#import "DDNotificationProtocols.h"

@interface DDNotificationSBControlSource : NSObject <DDNotificationControlSource>
- (BOOL)actuallySleepAfterIdlePresentation;
@property (nonatomic, assign) BOOL welcomed;
@property (nonatomic, assign) BOOL sleepAfterIdlePresentation;
@property (nonatomic, assign, setter=setDemoing:) BOOL isDemoing;
@end
