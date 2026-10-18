#import "SLWeChatSupportController.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string.h>
#include <stdlib.h>

// These are invocation signatures, not implementations or links against WeChat classes.
// Every private method is checked at runtime before it is called.
@protocol SLWeChatScanAPI <NSObject>
- (instancetype)initWithCodeType:(int)codeType fromScene:(int)scene;
- (instancetype)initWithCodeType:(int)codeType;
- (instancetype)initWithViewController:(UIViewController *)controller logicParams:(id)params;
- (instancetype)initWithDelegate:(id)delegate scannerParams:(id)params;
- (void)scanOnePicture:(UIImage *)image;
- (void)animateHideViews:(BOOL)hidden;
+ (id)defaultCenter;
- (id)getService:(Class)serviceClass;
- (id)scanLogicController;
- (void)setScanLogicController:(id)controller;
@end

NSBundle *SLWeChatSupportResources(void) {
	Dl_info info;
	if (!dladdr((const void *)&SLWeChatSupportResources, &info) || !info.dli_fname) return nil;
	NSString *library = [NSString stringWithUTF8String:info.dli_fname];
	for (NSUInteger i = 0; i < 3; i++) library = [library stringByDeletingLastPathComponent];
	return [NSBundle bundleWithPath:[library stringByAppendingPathComponent:@"PreferenceBundles/ShortLookSettings.bundle"]];
}

static const char *SLUnqualifiedType(const char *type) {
	while (type && *type && strchr("rnNoORV", *type)) type++;
	return type;
}

static BOOL SLCheckMethod(Class cls, SEL selector, const char *result, NSArray<NSString *> *arguments) {
	Method method = class_getInstanceMethod(cls, selector);
	if (!method || method_getNumberOfArguments(method) != arguments.count + 2) return NO;
	char type[128] = {0};
	method_getReturnType(method, type, sizeof(type));
	if (!*SLUnqualifiedType(type) || !strchr(result, *SLUnqualifiedType(type))) return NO;
	for (NSUInteger i = 0; i < arguments.count; i++) {
		method_getArgumentType(method, (unsigned int)i + 2, type, sizeof(type));
		if (!*SLUnqualifiedType(type) || !strchr(arguments[i].UTF8String, *SLUnqualifiedType(type))) return NO;
	}
	return YES;
}

// Preserve only the pre-existing scanner-controller reference, not messages or payment data.
static id SLReadCurrentScanLogic(id manager, BOOL *known) {
	*known = NO;
	if (SLCheckMethod(object_getClass(manager), @selector(scanLogicController), "@", @[])) {
		*known = YES;
		return [(id<SLWeChatScanAPI>)manager scanLogicController];
	}
	Ivar candidate = NULL;
	for (Class cls = object_getClass(manager); cls; cls = class_getSuperclass(cls)) {
		unsigned int count = 0;
		Ivar *ivars = class_copyIvarList(cls, &count);
		for (unsigned int i = 0; i < count; i++) {
			NSString *name = [[NSString stringWithUTF8String:ivar_getName(ivars[i])] lowercaseString];
			if (*ivar_getTypeEncoding(ivars[i]) == '@' && [name containsString:@"scan"] && [name containsString:@"logiccontroller"]) {
				if (candidate) { free(ivars); return nil; }
				candidate = ivars[i];
			}
		}
		free(ivars);
	}
	if (candidate) { *known = YES; return object_getIvar(manager, candidate); }
	return nil;
}

static char SLNativeSessionKey;

static UIViewController *SLFindRewardPage(UIViewController *root) {
	Class rewardClass = NSClassFromString(@"WCPayQRCodeRewardPayerDetailViewController");
	if (!root || !rewardClass) return nil;
	NSMutableArray<UIViewController *> *queue = [NSMutableArray arrayWithObject:root];
	NSMutableSet<UIViewController *> *seen = [NSMutableSet set];
	for (NSUInteger i = 0; i < queue.count && i < 128; i++) {
		UIViewController *controller = queue[i];
		if ([seen containsObject:controller]) continue;
		[seen addObject:controller];
		if ([controller isKindOfClass:rewardClass]) return controller;
		if (controller.presentedViewController) [queue addObject:controller.presentedViewController];
		[queue addObjectsFromArray:controller.childViewControllers];
		if ([controller isKindOfClass:[UINavigationController class]]) [queue addObjectsFromArray:[(UINavigationController *)controller viewControllers]];
	}
	return nil;
}

static void SLShowNativeEntryError(UIViewController *presenter, NSString *message) {
	if (!presenter.view.window || [UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
	while (presenter.presentedViewController) presenter = presenter.presentedViewController;
	if ([presenter isKindOfClass:[UIAlertController class]]) return;
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开微信赞赏" message:message preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
	[presenter presentViewController:alert animated:YES completion:nil];
}

@interface SLNativeAppreciationSession : NSObject
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong) UIViewController *imageContext;
@property (nonatomic, strong) id<SLWeChatScanAPI> scanLogic;
@property (nonatomic, strong) id<SLWeChatScanAPI> scanner;
@property (nonatomic, strong) id<SLWeChatScanAPI> resultsManager;
@property (nonatomic, strong) id previousScanLogic;
@property (nonatomic, assign) BOOL previousContextKnown;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic, strong) NSTimer *watchdog;
@property (nonatomic, strong) NSDate *deadline;
@property (nonatomic, weak) UIViewController *nativePage;
@property (nonatomic, assign) BOOL enteredNativePage;
@property (nonatomic, assign) BOOL finished;
- (void)start;
@end

@implementation SLNativeAppreciationSession

- (UIViewController *)applicationRoot {
	return self.window.rootViewController;
}

- (void)finish {
	if (self.finished) return;
	self.finished = YES;
	[self.watchdog invalidate];
	self.watchdog = nil;
	[self.indicator removeFromSuperview];
	self.indicator = nil;
	@try {
		BOOL known = NO;
		id current = self.resultsManager ? SLReadCurrentScanLogic(self.resultsManager, &known) : nil;
		// Never replace a scanner that WeChat has installed since this request.
		// An absent getter must not block the reference's native entry route.
		if (known && current == self.scanLogic) [self.resultsManager setScanLogicController:self.previousContextKnown ? self.previousScanLogic : nil];
	} @catch (NSException *ignored) { }
	self.scanner = nil;
	self.scanLogic = nil;
	self.resultsManager = nil;
	self.previousScanLogic = nil;
	[self.imageContext willMoveToParentViewController:nil];
	[self.imageContext removeFromParentViewController];
	self.imageContext = nil;
	UIViewController *owner = self.presenter;
	if (objc_getAssociatedObject(owner, &SLNativeSessionKey) == self) objc_setAssociatedObject(owner, &SLNativeSessionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)fail:(NSString *)reason {
	UIViewController *presenter = self.presenter;
	[self finish];
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知";
	SLShowNativeEntryError(presenter, [NSString stringWithFormat:@"%@\n微信版本：%@。未发起付款。", reason, version]);
}

- (void)checkNativeEntry {
	if (self.finished) return;
	if (!self.window.rootViewController) { [self finish]; return; }
	if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
	UIViewController *page = SLFindRewardPage([self applicationRoot]);
	if (!self.enteredNativePage && page) {
		// Recognize actual native page entry, never URL acceptance or scanner submission.
		self.enteredNativePage = YES;
		self.nativePage = page;
		self.deadline = [NSDate dateWithTimeIntervalSinceNow:300];
		[self.indicator removeFromSuperview];
		self.indicator = nil;
	}
	if (self.enteredNativePage) {
		if (!page || !self.nativePage || [self.deadline timeIntervalSinceNow] <= 0) [self finish];
	} else if ([self.deadline timeIntervalSinceNow] <= 0) {
		[self fail:@"微信未打开原生赞赏金额页，已停止本次请求。请反馈此提示和微信版本。"];
	}
}

- (void)start {
	@try {
		Class logicClass = NSClassFromString(@"ScanQRCodeLogicController");
		Class paramsClass = NSClassFromString(@"ScanQRCodeLogicParams");
		Class scannerParamsClass = NSClassFromString(@"NewQRCodeScannerParams");
		Class scannerClass = NSClassFromString(@"NewQRCodeScanner");
		Class imageClass = NSClassFromString(@"MsgImgFullScreenViewController");
		Class centerClass = NSClassFromString(@"MMServiceCenter");
		Class managerClass = NSClassFromString(@"ScanQRCodeResultsMgr");
		Class rewardClass = NSClassFromString(@"WCPayQRCodeRewardPayerDetailViewController");
		// Both 32/64-bit integer enum signatures use the same arm64 argument registers
		// for these positive, fixed values; reject objects/floats/unknown arguments.
		BOOL supported = imageClass && [imageClass isSubclassOfClass:[UIViewController class]] && rewardClass &&
			SLCheckMethod(paramsClass, @selector(initWithCodeType:fromScene:), "@", @[@"iIqQ", @"iIqQ"]) &&
			SLCheckMethod(scannerParamsClass, @selector(initWithCodeType:), "@", @[@"iIqQ"]) &&
			SLCheckMethod(logicClass, @selector(initWithViewController:logicParams:), "@", @[@"@", @"@"]) &&
			SLCheckMethod(scannerClass, @selector(initWithDelegate:scannerParams:), "@", @[@"@", @"@"]) &&
			SLCheckMethod(scannerClass, @selector(scanOnePicture:), "v", @[@"@"]) &&
			SLCheckMethod(object_getClass(centerClass), @selector(defaultCenter), "@", @[]) &&
			SLCheckMethod(centerClass, @selector(getService:), "@", @[@"#@"]) &&
			SLCheckMethod(managerClass, @selector(setScanLogicController:), "v", @[@"@"]);
		if (!supported) { [self fail:@"当前微信的原生赞赏入口接口不匹配。没有切换到其他收款方式。"];
			return; }
		if (SLFindRewardPage([self applicationRoot])) {
			[self fail:@"微信已有赞赏页面，请先退出该页面，再从 ShortLook 重新打开，以免混淆收款方。"];
			return;
		}
		NSBundle *bundle = SLWeChatSupportResources();
		NSString *path = [bundle pathForResource:@"Support" ofType:@"plist"];
		NSDictionary *configuration = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
		NSString *name = configuration[@"WeChatQRCode"];
		if (![name isKindOfClass:[NSString class]] || ![name isEqualToString:name.lastPathComponent] || ![@[@"jpg", @"jpeg", @"png"] containsObject:name.pathExtension.lowercaseString]) {
			[self fail:@"随包赞赏资料缺失。"];
			return;
		}
		NSString *imagePath = [bundle pathForResource:name ofType:nil];
		UIImage *internalImage = imagePath ? [UIImage imageWithContentsOfFile:imagePath] : nil;
		if (!internalImage) { [self fail:@"无法读取随包赞赏资料。"];
			return; }
		self.imageContext = [[imageClass alloc] init];
		if (!self.imageContext) { [self fail:@"微信未创建原生赞赏上下文。"];
			return; }
		// Match the supplied reference: a native image context for decoding, NOT a
		// visible image/QR screen. Its view is never added or presented by this code.
		[self.presenter addChildViewController:self.imageContext];
		[self.imageContext didMoveToParentViewController:self.presenter];
		if (SLCheckMethod(imageClass, @selector(animateHideViews:), "v", @[@"Bc"])) [(id<SLWeChatScanAPI>)self.imageContext animateHideViews:YES];

		id params = [(id<SLWeChatScanAPI>)[paramsClass alloc] initWithCodeType:27 fromScene:2];
		id scannerParams = [(id<SLWeChatScanAPI>)[scannerParamsClass alloc] initWithCodeType:27];
		self.scanLogic = [(id<SLWeChatScanAPI>)[logicClass alloc] initWithViewController:self.imageContext logicParams:params];
		id<SLWeChatScanAPI> center = [(Class<SLWeChatScanAPI>)centerClass defaultCenter];
		self.resultsManager = [center getService:managerClass];
		self.scanner = [(id<SLWeChatScanAPI>)[scannerClass alloc] initWithDelegate:self.scanLogic scannerParams:scannerParams];
		if (!params || !scannerParams || !self.scanLogic || !self.resultsManager || !self.scanner) {
			[self fail:@"微信原生赞赏组件未就绪。"];
			return;
		}
		BOOL previousKnown = NO;
		@try { self.previousScanLogic = SLReadCurrentScanLogic(self.resultsManager, &previousKnown); }
		@catch (NSException *ignored) { previousKnown = NO; }
		self.previousContextKnown = previousKnown;
		[self.resultsManager setScanLogicController:self.scanLogic];

		self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
		self.indicator.translatesAutoresizingMaskIntoConstraints = NO;
		self.indicator.accessibilityLabel = @"正在打开微信赞赏";
		[self.presenter.view addSubview:self.indicator];
		[NSLayoutConstraint activateConstraints:@[
			[self.indicator.centerXAnchor constraintEqualToAnchor:self.presenter.view.centerXAnchor],
			[self.indicator.centerYAnchor constraintEqualToAnchor:self.presenter.view.centerYAnchor]
		]];
		[self.indicator startAnimating];
		self.deadline = [NSDate dateWithTimeIntervalSinceNow:15];
		__weak SLNativeAppreciationSession *weakSelf = self;
		self.watchdog = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) {
			SLNativeAppreciationSession *session = weakSelf;
			if (session) [session checkNativeEntry]; else [timer invalidate];
		}];
		// The next visible support screen must be WeChat's own amount picker.
		[self.scanner scanOnePicture:internalImage];
	} @catch (NSException *exception) {
		[self fail:[NSString stringWithFormat:@"微信原生赞赏入口异常（%@），已停止。", exception.name]];
	}
}

@end

void SLOpenWeChatNativeAppreciation(UIViewController *presenter) {
	if (!presenter.view.window || [UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
	if (objc_getAssociatedObject(presenter, &SLNativeSessionKey)) return;
	SLNativeAppreciationSession *session = [[SLNativeAppreciationSession alloc] init];
	session.presenter = presenter;
	session.window = presenter.view.window;
	objc_setAssociatedObject(presenter, &SLNativeSessionKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[session start];
}
