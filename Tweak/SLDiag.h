// Diagnostic logging for the iOS 16 port (not part of the original ShortLook).
// Log file: /var/mobile/Library/Caches/ShortLook/debug.log
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
void SLDiagLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
void SLDiagDumpRuntime(void);
#ifdef __cplusplus
}
#endif
