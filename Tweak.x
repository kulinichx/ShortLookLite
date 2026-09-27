// ShortLook Lite — 锁屏通知全屏大头像（iOS 16 / RootHide 精简重写版）
//
// 节能原则：不主动点亮屏幕、不延长亮屏。
// 新通知进来后，只在「系统自己把屏幕点亮」的那段时间里显示；屏幕熄灭或回到 AOD、解锁、点击即关闭。

#import "Sources/SLLCommon.h"
#import "Sources/SLLAvatar.h"
#import "Sources/SLLOverlayView.h"
#import <objc/runtime.h>

#define SLL_VERSION @"0.1.0"

static const NSTimeInterval kWaitForScreenOn = 2.5;   // 通知到达后等系统亮屏的最长时间
static const NSTimeInterval kMaxNotificationAge = 15; // 更早的通知（如重启后恢复的）不显示
static const NSTimeInterval kTickInterval = 0.2;      // 只在「等待亮屏 / 显示中」时轮询

#pragma mark - 设置

static BOOL pEnabled = YES;
static NSInteger pDuration = 0;   // 0 = 跟随屏幕；>0 = 秒
static NSInteger pContent = 0;    // 0 跟随系统，1 总是显示，2 不显示
static BOOL pShowTime = YES;
static BOOL pDebug = YES;

static id SLLPref(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)SLL_DOMAIN));
}

static void SLLLoadPrefs(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)SLL_DOMAIN);
    id v;
    v = SLLPref(@"enabled");  pEnabled  = v ? [v boolValue] : YES;
    v = SLLPref(@"duration"); pDuration = v ? [v integerValue] : 0;
    v = SLLPref(@"content");  pContent  = v ? [v integerValue] : 0;
    v = SLLPref(@"showTime"); pShowTime = v ? [v boolValue] : YES;
    v = SLLPref(@"debugLog"); pDebug    = v ? [v boolValue] : YES;
    SLLSetLogEnabled(pDebug);
}

#pragma mark - 数据

@interface SLLItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) NSInteger previewSetting;   // 0 总是，1 解锁时，2 从不（同 UNShowPreviewsSetting）
@property (nonatomic, strong) SLLAvatarRequest *avatarRequest;
@property (nonatomic, strong) UIImage *avatar;
@property (nonatomic, copy) NSString *avatarSource;
@property (nonatomic, assign) BOOL avatarDone;
@property (nonatomic, assign) BOOL isTest;
@end

@implementation SLLItem
@end

static UIImage *SLLAppIcon(NSString *bundleID) {
    if (!bundleID.length) return nil;
    if (![UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) return nil;
    return [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:[UIScreen mainScreen].scale];
}

static NSString *SLLShort(id obj, NSUInteger max) {
    NSString *s = [[obj description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    return s.length > max ? [[s substringToIndex:max] stringByAppendingString:@"…"] : s;
}

// 从通知请求的各处收集 userInfo（微信 u / QQ r 所在位置待实机确认，这里全部合并）
static NSDictionary *SLLCollectUserInfo(id req, NSMutableString *log) {
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    NSArray *paths = @[@"context.userInfo", @"userInfo", @"bulletin.context.userInfo",
                       @"content.userInfo", @"context", @"bulletin.context"];
    for (NSString *p in paths) {
        id d = SLLKVPath(req, p);
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        [log appendFormat:@" %@=%@", p, [[d allKeys] componentsJoinedByString:@","]];
        for (id k in d) if (!merged[k]) merged[k] = d[k];
    }
    return merged;
}

#pragma mark - 悬浮窗兜底（找不到锁屏视图时才用）

@interface SLLSecureWindow : UIWindow
@end

@implementation SLLSecureWindow
- (BOOL)_shouldCreateContextAsSecure { return YES; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    return v == self ? nil : v;
}
@end

#pragma mark - 控制器

static __weak UIViewController *gCoverSheet;

@interface SLLController : NSObject
+ (instancetype)shared;
- (void)handleRequest:(id)req source:(NSString *)source;
- (void)enqueueTest;
- (void)dismiss:(NSString *)reason;
@end

@implementation SLLController {
    SLLOverlayView *_overlay;
    SLLSecureWindow *_fallbackWindow;
    SLLItem *_shown;
    SLLItem *_pending;
    NSDate *_pendingDeadline;
    NSDate *_shownAt;
    NSTimer *_timer;
    NSMutableArray<NSString *> *_seen;
    SLLScreenState _lastState;
}

+ (instancetype)shared {
    static SLLController *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [self new]; });
    return c;
}

- (instancetype)init {
    if ((self = [super init])) {
        _seen = [NSMutableArray array];
        _lastState = SLLScreenUnknown;
    }
    return self;
}

#pragma mark 通知进来

- (void)handleRequest:(id)req source:(NSString *)source {
    if (!pEnabled || !req) return;

    NSString *ident = SLLStr(SLLKV(req, @"notificationIdentifier")) ?: [NSString stringWithFormat:@"%p", req];
    if ([_seen containsObject:ident]) return;
    [_seen addObject:ident];
    if (_seen.count > 80) [_seen removeObjectAtIndex:0];

    NSString *bid = SLLStr(SLLKV(req, @"sectionIdentifier")) ?: SLLStr(SLLKVPath(req, @"bulletin.sectionID"));
    NSDate *ts = SLLKV(req, @"timestamp");
    if ([ts isKindOfClass:[NSDate class]] && -[ts timeIntervalSinceNow] > kMaxNotificationAge) return;

    if (!SLLIsUILocked()) {
        SLLLog(@"[%@] %@ 未锁屏，跳过", source, bid);
        return;
    }

    id content = SLLKV(req, @"content");
    NSString *title = SLLStr(SLLKV(content, @"title"));
    NSString *subtitle = SLLStr(SLLKV(content, @"subtitle"));
    NSString *message = SLLStr(SLLKV(content, @"message"));
    if (!title.length && !message.length) {
        SLLLog(@"[%@] %@ 无标题无内容，跳过", source, bid);
        return;
    }
    if (!title.length) title = SLLStr(SLLKV(content, @"header")) ?: @"";
    if (subtitle.length) message = message.length ? [NSString stringWithFormat:@"%@\n%@", subtitle, message] : subtitle;

    NSMutableString *uiLog = [NSMutableString string];
    NSDictionary *userInfo = SLLCollectUserInfo(req, uiLog);

    NSInteger preview = -1;
    NSString *previewFrom = @"默认";
    for (NSString *p in @[@"options.contentPreviewSetting", @"bulletin.contentPreviewSetting"]) {
        id v = SLLKVPath(req, p);
        if ([v isKindOfClass:[NSNumber class]]) { preview = [v integerValue]; previewFrom = p; break; }
    }
    if (preview < 0) preview = 1;   // 读不到就按 iOS 默认「解锁时」

    SLLAvatarRequest *ar = [SLLAvatarRequest new];
    ar.bundleID = bid;
    ar.userInfo = userInfo;
    id comm = SLLKV(content, @"communicationContext") ?: SLLKVPath(req, @"bulletin.communicationContext");
    id sender = SLLKV(comm, @"sender");
    ar.contactIdentifier = SLLStr(SLLKV(sender, @"cnContactIdentifier")) ?: SLLStr(SLLKV(sender, @"contactIdentifier"));
    ar.handle = SLLStr(SLLKV(sender, @"handle"));
    if (comm) {
        id icons = SLLKV(content, @"icons");
        id icon = [icons isKindOfClass:[NSArray class]] ? [icons firstObject] : SLLKV(content, @"icon");
        if ([icon isKindOfClass:[UIImage class]]) ar.fallbackImage = icon;
    }

    SLLItem *item = [SLLItem new];
    item.identifier = ident;
    item.bundleID = bid;
    item.title = title;
    item.message = message;
    item.previewSetting = preview;
    item.avatarRequest = ar;

    if (pDebug) {
        NSString *d = nil;
        SLLScreenState st = SLLGetScreenState(&d);
        SLLLog(@"[%@] 新通知 %@ 标题长%lu 内容长%lu 屏幕=%@ %@ 预览=%ld(%@)", source, bid,
               (unsigned long)title.length, (unsigned long)message.length, SLLScreenStateName(st), d, (long)preview, previewFrom);
        SLLLog(@"   userInfo 来源:%@ | u=%@ r=%@", uiLog, SLLStr(userInfo[@"u"]), SLLStr(userInfo[@"r"]));
        SLLLog(@"   通讯类=%@ 联系人=%@ handle=%@ 自带图=%d options=%@", comm ? @"是" : @"否",
               ar.contactIdentifier, ar.handle, ar.fallbackImage != nil, SLLShort(SLLKV(req, @"options"), 300));
    }
    [self enqueue:item wait:kWaitForScreenOn];
}

- (void)enqueueTest {
    SLLItem *item = [SLLItem new];
    item.identifier = [[NSUUID UUID] UUIDString];
    item.bundleID = @"com.apple.Preferences";
    item.title = @"ShortLook Lite";
    item.message = @"测试通知：看到这一屏说明显示正常。\n点一下或滑一下关闭。";
    item.previewSetting = 0;
    item.isTest = YES;
    SLLAvatarRequest *ar = [SLLAvatarRequest new];
    ar.bundleID = item.bundleID;
    item.avatarRequest = ar;
    SLLLog(@"收到测试请求：20 秒内锁屏并按侧键点亮即可看到");
    [self enqueue:item wait:20];
}

- (void)enqueue:(SLLItem *)item wait:(NSTimeInterval)wait {
    _pending = item;
    _pendingDeadline = [NSDate dateWithTimeIntervalSinceNow:wait];
    [[SLLAvatarProvider shared] fetch:item.avatarRequest completion:^(UIImage *image, NSString *src) {
        item.avatar = image;
        item.avatarSource = src;
        item.avatarDone = YES;
        SLLLog(@"头像结果 %@ -> %@", item.bundleID, src ?: @"无（用 App 图标）");
        if (self->_shown == item) [self applyAvatar:item animated:YES];
    }];
    [self tick];
    [self ensureTimer];
}

#pragma mark 轮询

- (void)ensureTimer {
    if (_timer || (!_overlay && !_pending)) return;
    _timer = [NSTimer timerWithTimeInterval:kTickInterval target:self selector:@selector(tick) userInfo:nil repeats:YES];
    _timer.tolerance = 0.05;
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    [_timer invalidate];
    _timer = nil;
}

- (void)tick {
    NSString *detail = nil;
    SLLScreenState st = SLLGetScreenState(&detail);
    BOOL locked = SLLIsUILocked();
    if (st != _lastState) {
        SLLLog(@"屏幕 %@ -> %@ (%@)", SLLScreenStateName(_lastState), SLLScreenStateName(st), detail);
        _lastState = st;
    }

    if (_overlay) {
        if (!locked) [self dismiss:@"已解锁"];
        else if (st != SLLScreenOn) [self dismiss:[@"屏幕" stringByAppendingString:SLLScreenStateName(st)]];
        else if (pDuration > 0 && -[_shownAt timeIntervalSinceNow] >= pDuration) [self dismiss:@"到时"];
        else {
            [_overlay refreshClock];
            [self updateMessageVisibility];
        }
    }

    if (_pending) {
        if ([_pendingDeadline timeIntervalSinceNow] < 0) {
            SLLLog(@"系统没有点亮屏幕，不显示（%@）", _pending.bundleID);
            _pending = nil;
        } else if (!locked && !_pending.isTest) {
            _pending = nil;
        } else if (locked && st == SLLScreenOn) {
            SLLItem *item = _pending;
            _pending = nil;
            [self show:item];
        }
    }

    if (!_overlay && !_pending) [self stopTimer];
}

#pragma mark 显示 / 关闭

- (UIView *)hostView {
    UIViewController *cs = gCoverSheet;
    if (!cs) {
        SBLockScreenManager *m = [objc_getClass("SBLockScreenManager") sharedInstance];
        if ([m respondsToSelector:@selector(coverSheetViewController)]) cs = [m coverSheetViewController];
    }
    if (cs.isViewLoaded && cs.view.window && !cs.view.window.hidden) return cs.view;
    return nil;
}

- (void)show:(SLLItem *)item {
    NSString *hostName = @"已存在";
    if (!_overlay) {
        UIView *host = [self hostView];
        if (host) {
            _overlay = [[SLLOverlayView alloc] initWithFrame:host.bounds];
            [host addSubview:_overlay];
            hostName = NSStringFromClass([host class]);
        } else {
            UIWindowScene *scene = nil;
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] && ((UIWindowScene *)s).screen == [UIScreen mainScreen]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            _fallbackWindow = scene ? [[SLLSecureWindow alloc] initWithWindowScene:scene]
                                    : [[SLLSecureWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            _fallbackWindow.frame = [UIScreen mainScreen].bounds;
            _fallbackWindow.windowLevel = 1100;
            _fallbackWindow.backgroundColor = [UIColor clearColor];
            _fallbackWindow.hidden = NO;
            _overlay = [[SLLOverlayView alloc] initWithFrame:_fallbackWindow.bounds];
            [_fallbackWindow addSubview:_overlay];
            hostName = @"兜底窗口";
        }
        __weak SLLController *weakSelf = self;
        _overlay.onDismissRequest = ^(NSString *reason) { [weakSelf dismiss:reason]; };
        _overlay.alpha = 0;
        SLLOverlayView *v = _overlay;
        [UIView animateWithDuration:0.2 animations:^{ v.alpha = 1; }];
    } else {
        [_overlay.superview bringSubviewToFront:_overlay];
    }

    _shown = item;
    _shownAt = [NSDate date];
    _overlay.showsClock = pShowTime;
    [_overlay refreshClock];
    [_overlay setName:item.title message:item.message appIcon:SLLAppIcon(item.bundleID)];
    [self updateMessageVisibility];
    [self applyAvatar:item animated:NO];
    SLLLog(@"显示 %@ 宿主=%@ 头像=%@", item.bundleID, hostName, item.avatarDone ? (item.avatarSource ?: @"App图标") : @"加载中");
    [self ensureTimer];
}

- (void)applyAvatar:(SLLItem *)item animated:(BOOL)animated {
    if (!_overlay) return;
    if (item.avatar) {
        [_overlay setAvatar:item.avatar isAppIcon:NO animated:animated];
    } else if (item.avatarDone) {
        [_overlay setAvatar:SLLAppIcon(item.bundleID) isAppIcon:YES animated:animated];
    } else {
        [_overlay setAvatar:nil isAppIcon:NO animated:NO];   // 加载中：深色圆
    }
}

- (void)updateMessageVisibility {
    if (!_overlay || !_shown) return;
    BOOL hide;
    switch (pContent) {
        case 1:  hide = NO; break;
        case 2:  hide = YES; break;
        default: hide = _shown.previewSetting == 2 || (_shown.previewSetting == 1 && !SLLDeviceAuthenticated()); break;
    }
    [_overlay setMessageHidden:hide];
}

- (void)dismiss:(NSString *)reason {
    if (!_overlay) return;
    SLLOverlayView *v = _overlay;
    SLLSecureWindow *w = _fallbackWindow;
    _overlay = nil;
    _fallbackWindow = nil;
    _shown = nil;
    SLLLog(@"关闭：%@", reason);
    [UIView animateWithDuration:0.2 animations:^{ v.alpha = 0; } completion:^(BOOL finished) {
        [v removeFromSuperview];
        w.hidden = YES;
    }];
    if (!_pending) [self stopTimer];
}

@end

#pragma mark - Hooks

static void SLLHandle(id req, NSString *source) {
    if ([NSThread isMainThread]) {
        [[SLLController shared] handleRequest:req source:source];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ [[SLLController shared] handleRequest:req source:source]; });
    }
}

// 锁屏 / 通知中心列表插入新通知（iOS 16 上 Axon 已验证）
%hook NCNotificationStructuredListViewController
- (BOOL)insertNotificationRequest:(id)request {
    BOOL r = %orig;
    SLLHandle(request, @"list");
    return r;
}
%end

// 通知分发（兜底，和上面去重）
%hook NCNotificationDispatcher
- (void)postNotificationWithRequest:(id)request {
    %orig;
    SLLHandle(request, @"dispatch");
}
%end

%hook CSCoverSheetViewController
- (void)viewDidLoad {
    %orig;
    gCoverSheet = (UIViewController *)self;
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    gCoverSheet = (UIViewController *)self;
}
%end

#pragma mark - 初始化

static void SLLPrefsChanged(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef ui) {
    SLLLoadPrefs();
    SLLLog(@"设置已更新 enabled=%d duration=%ld content=%ld showTime=%d", pEnabled, (long)pDuration, (long)pContent, pShowTime);
    if (!pEnabled) [[SLLController shared] dismiss:@"已关闭插件"];
}

static void SLLClearCache(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef ui) {
    [[SLLAvatarProvider shared] clearCache];
}

static void SLLTest(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef ui) {
    [[SLLController shared] enqueueTest];
}

%ctor {
    SLLLoadPrefs();
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, SLLPrefsChanged, CFSTR(SLL_NOTIFY_PREFS), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, SLLClearCache, CFSTR(SLL_NOTIFY_CLEAR), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, SLLTest, CFSTR(SLL_NOTIFY_TEST), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    %init;
    SLLLog(@"==== ShortLook Lite %@ 已加载（enabled=%d）====", SLL_VERSION, pEnabled);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (pDebug) SLLDumpDiagnostics();
    });
}
