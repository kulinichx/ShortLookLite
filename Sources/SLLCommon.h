// ShortLook Lite — 公共声明
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define SLL_DOMAIN        @"com.kokol.shortlooklite"
#define SLL_NOTIFY_PREFS  "com.kokol.shortlooklite/prefs"
#define SLL_NOTIFY_CLEAR  "com.kokol.shortlooklite/clearcache"
#define SLL_NOTIFY_TEST   "com.kokol.shortlooklite/test"

#ifdef __cplusplus
extern "C" {
#endif

// ---------- 日志（/var/mobile/Library/Caches/ShortLookLite/sll.log） ----------
void SLLSetLogEnabled(BOOL enabled);
BOOL SLLLogEnabled(void);
void SLLLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
NSString *SLLCacheDir(void);

// ---------- 安全取值（未知 key 不会抛异常） ----------
id SLLKV(id obj, NSString *key);
id SLLKVPath(id obj, NSString *dottedPath);
NSString *SLLStr(id obj);           // NSString/NSNumber -> NSString，其它返回 nil
NSString *SLLMD5(NSString *s);

// ---------- 屏幕 / 锁屏状态 ----------
typedef NS_ENUM(NSInteger, SLLScreenState) {
    SLLScreenUnknown = -1,
    SLLScreenOff     = 0,   // 黑屏
    SLLScreenAOD     = 1,   // 全天候显示（暗）
    SLLScreenOn      = 2,   // 正常点亮（含变暗前的 Dimmed）
};
SLLScreenState SLLGetScreenState(NSString **detail);
NSString *SLLScreenStateName(SLLScreenState s);
BOOL SLLIsUILocked(void);
BOOL SLLDeviceAuthenticated(void);  // Face ID 已解锁（仍停在锁屏）或未设密码
void SLLDumpDiagnostics(void);      // 调试：把相关私有类的方法名写进日志

#ifdef __cplusplus
}
#endif

// ---------- 私有 API 声明 ----------
@interface UIImage (SLLPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (UIViewController *)coverSheetViewController;
@end

@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)bundleID;
- (NSURL *)dataContainerURL;
@end

@interface LSApplicationRecord : NSObject
- (instancetype)initWithBundleIdentifier:(NSString *)bundleID allowPlaceholder:(BOOL)allow error:(NSError **)error;
- (NSURL *)dataContainerURL;
@end
