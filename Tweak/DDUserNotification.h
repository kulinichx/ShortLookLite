#import "DDAbstractNotification.h"
#import "Private.h"

@interface DDUserNotification : DDAbstractNotification <DDNotificationRefreshable>
+ (BOOL)canShowSupressedContent;
- (instancetype)initWithNotificationRequest:(NCNotificationRequest *)request;
- (UNNotificationContent *)content;
- (BOOL)isSupressingContentForUnlock;
- (NSDictionary *)applicationUserInfo;
@property (nonatomic, readonly) NCNotificationRequest *request;
@end
