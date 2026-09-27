// ShortLook Lite — 日志、安全取值、屏幕状态
#import "SLLCommon.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>

#pragma mark - 日志

static BOOL gLogEnabled = YES;
void SLLSetLogEnabled(BOOL enabled) { gLogEnabled = enabled; }
BOOL SLLLogEnabled(void) { return gLogEnabled; }

NSString *SLLCacheDir(void) {
    static NSString *dir;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dir = @"/var/mobile/Library/Caches/ShortLookLite";
        [[NSFileManager defaultManager] createDirectoryAtPath:[dir stringByAppendingPathComponent:@"avatars"]
                                  withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

void SLLLog(NSString *format, ...) {
    if (!gLogEnabled) return;
    va_list ap;
    va_start(ap, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    NSLog(@"[SLL] %@", msg);

    static dispatch_queue_t q;
    static NSDateFormatter *df;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.kokol.shortlooklite.log", DISPATCH_QUEUE_SERIAL);
        df = [NSDateFormatter new];
        df.dateFormat = @"MM-dd HH:mm:ss.SSS";
    });
    NSDate *now = [NSDate date];
    dispatch_async(q, ^{
        NSString *path = [SLLCacheDir() stringByAppendingPathComponent:@"sll.log"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
        if (attr && [attr fileSize] > 512 * 1024) {
            NSString *old = [path stringByAppendingString:@".old"];
            [fm removeItemAtPath:old error:nil];
            [fm moveItemAtPath:path toPath:old error:nil];
        }
        if (![fm fileExistsAtPath:path]) [fm createFileAtPath:path contents:nil attributes:nil];
        NSString *line = [NSString stringWithFormat:@"%@ %@\n", [df stringFromDate:now], msg];
        NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:path];
        [h seekToEndOfFile];
        [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [h closeFile];
    });
}

#pragma mark - 安全取值

id SLLKV(id obj, NSString *key) {
    if (!obj || !key.length) return nil;
    if ([obj isKindOfClass:[NSDictionary class]]) return ((NSDictionary *)obj)[key];
    if (![obj respondsToSelector:NSSelectorFromString(key)]) return nil;
    @try {
        return [obj valueForKey:key];
    } @catch (NSException *e) {
        return nil;
    }
}

id SLLKVPath(id obj, NSString *dottedPath) {
    id cur = obj;
    for (NSString *k in [dottedPath componentsSeparatedByString:@"."]) {
        cur = SLLKV(cur, k);
        if (!cur) return nil;
    }
    return cur;
}

NSString *SLLStr(id obj) {
    if ([obj isKindOfClass:[NSString class]]) return obj;
    if ([obj isKindOfClass:[NSNumber class]]) return [obj stringValue];
    return nil;
}

NSString *SLLMD5(NSString *s) {
    const char *c = s.UTF8String ?: "";
    unsigned char d[CC_MD5_DIGEST_LENGTH];
    CC_MD5(c, (CC_LONG)strlen(c), d);
    NSMutableString *out = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [out appendFormat:@"%02x", d[i]];
    return out;
}

#pragma mark - 屏幕状态

static id SLLBacklight(void) {
    Class c = objc_getClass("BLSBacklight");
    if (!c) {
        dlopen("/System/Library/PrivateFrameworks/BacklightServices.framework/BacklightServices", RTLD_LAZY);
        c = objc_getClass("BLSBacklight");
    }
    if (!c) return nil;
    for (NSString *name in @[@"sharedBacklight", @"sharedInstance", @"shared"]) {
        SEL sel = NSSelectorFromString(name);
        if ([c respondsToSelector:sel]) return ((id (*)(id, SEL))objc_msgSend)(c, sel);
    }
    return nil;
}

NSString *SLLScreenStateName(SLLScreenState s) {
    switch (s) {
        case SLLScreenOff: return @"熄屏";
        case SLLScreenAOD: return @"AOD";
        case SLLScreenOn:  return @"亮屏";
        default:           return @"未知";
    }
}

SLLScreenState SLLGetScreenState(NSString **detail) {
    NSMutableString *d = detail ? [NSMutableString string] : nil;
    SLLScreenState result = SLLScreenUnknown;

    // 1) BacklightServices（iOS 16，区分 Off / InactiveOn(AOD) / ActiveOn / Dimmed）
    id bl = SLLBacklight();
    SEL stSel = NSSelectorFromString(@"backlightState");
    if (bl && [bl respondsToSelector:stSel]) {
        long long st = ((long long (*)(id, SEL))objc_msgSend)(bl, stSel);
        static NSString *(*toStr)(long long);
        static dispatch_once_t once;
        dispatch_once(&once, ^{ toStr = (NSString *(*)(long long))dlsym(RTLD_DEFAULT, "NSStringFromBLSBacklightState"); });
        NSString *name = toStr ? toStr(st) : nil;
        [d appendFormat:@"bls=%lld(%@) ", st, name];
        NSString *ln = name.lowercaseString;
        if (ln.length) {
            if ([ln containsString:@"inactive"])      result = SLLScreenAOD;
            else if ([ln containsString:@"off"])      result = SLLScreenOff;
            else if ([ln containsString:@"active"] ||
                     [ln containsString:@"dim"])      result = SLLScreenOn;
        }
    } else {
        [d appendString:@"bls=n/a "];
    }

    // 2) Darwin 通知状态（兜底；AOD 下取值待实机确认）
    static int token = 0;
    static dispatch_once_t once2;
    dispatch_once(&once2, ^{ notify_register_check("com.apple.springboard.hasBlankedScreen", &token); });
    uint64_t blanked = 0;
    if (token) notify_get_state(token, &blanked);
    [d appendFormat:@"blanked=%llu ", blanked];

    if (result == SLLScreenUnknown) result = blanked ? SLLScreenOff : SLLScreenOn;
    if (detail) *detail = d;
    return result;
}

BOOL SLLIsUILocked(void) {
    Class c = objc_getClass("SBLockScreenManager");
    SBLockScreenManager *m = [c sharedInstance];
    if ([m respondsToSelector:@selector(isUILocked)]) return [m isUILocked];
    return NO;
}

BOOL SLLDeviceAuthenticated(void) {
    static int (*getState)(CFDictionaryRef);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/MobileKeyBag.framework/MobileKeyBag", RTLD_LAZY);
        if (h) getState = (int (*)(CFDictionaryRef))dlsym(h, "MKBGetDeviceLockState");
    });
    if (!getState) return NO;
    int st = getState(NULL);
    return st == 0 || st == 3;  // 0 已解锁，3 未设密码
}

static void SLLDumpClass(NSString *name, NSArray<NSString *> *needles) {
    Class c = objc_getClass(name.UTF8String);
    if (!c) { SLLLog(@"[诊断] 类 %@ 不存在", name); return; }
    NSMutableArray *hits = [NSMutableArray array];
    for (int meta = 0; meta < 2; meta++) {
        Class k = meta ? object_getClass((id)c) : c;
        unsigned int n = 0;
        Method *ms = class_copyMethodList(k, &n);
        for (unsigned int i = 0; i < n; i++) {
            NSString *sel = NSStringFromSelector(method_getName(ms[i]));
            for (NSString *nd in needles) {
                if ([sel.lowercaseString containsString:nd]) {
                    [hits addObject:[NSString stringWithFormat:@"%@%@", meta ? @"+" : @"-", sel]];
                    break;
                }
            }
        }
        free(ms);
    }
    SLLLog(@"[诊断] %@: %@", name, [hits componentsJoinedByString:@" "]);
}

void SLLDumpDiagnostics(void) {
    SLLDumpClass(@"BLSBacklight", @[@"shared", @"state"]);
    SLLDumpClass(@"SBBacklightController", @[@"shared", @"screen", @"state"]);
    SLLDumpClass(@"SBNCScreenController", @[@"screen", @"turnon", @"wake"]);
    SLLDumpClass(@"SBNCAlertingController", @[@"alert", @"screen", @"wake"]);
    SLLDumpClass(@"NCNotificationStructuredListViewController", @[@"insertnotificationrequest"]);
    SLLDumpClass(@"NCNotificationDispatcher", @[@"postnotification"]);
    SLLDumpClass(@"NCNotificationContent", @[@"icon", @"communication", @"title", @"message"]);
    SLLDumpClass(@"NCNotificationOptions", @[@"preview", @"alert", @"locked"]);
    NSString *d = nil;
    SLLScreenState s = SLLGetScreenState(&d);
    SLLLog(@"[诊断] 当前屏幕=%@ %@ 锁屏=%d 已认证=%d", SLLScreenStateName(s), d, SLLIsUILocked(), SLLDeviceAuthenticated());
}
