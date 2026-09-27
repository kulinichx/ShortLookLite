#import "DDNotificationProtocols.h"
#import "DDApplication.h"

@interface DDCoalescedNotification : NSObject <DDNotificationDisplayable, DDCoalescableNotification, DDUserNotificationContactPhotoProxying>
- (instancetype)initWithNotifications:(NSArray *)notifications;
- (DDApplication *)application;
- (BOOL)canProxyNotificationForContactPhoto;
@property (nonatomic, retain) NSArray *notifications;
@end
