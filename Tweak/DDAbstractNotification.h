#import "DDNotificationProtocols.h"
#import "DDApplication.h"

@interface DDAbstractNotification : NSObject <DDNotificationDisplayable, DDCoalescableNotification>
- (instancetype)initWithNotificationTitle:(NSString *)notificationTitle application:(DDApplication *)application;
- (instancetype)initWithNotificationTitle:(NSString *)notificationTitle notificationSubtitle:(NSString *)notificationSubtitle notificationBody:(NSString *)notificationBody application:(DDApplication *)application;
- (BOOL)hasCustomTitle;
- (BOOL)hasCustomSubtitle;
@property (nonatomic, readonly) DDApplication *application;
@property (nonatomic, readonly) NSString *notificationTitle;
@property (nonatomic, readonly) NSString *notificationSubtitle;
@property (nonatomic, readonly) NSString *notificationBody;
@property (nonatomic, retain) NSDictionary *userInfo;
@property (nonatomic, retain) NSString *_titleOverride;
@property (nonatomic, retain) NSString *_subtitleOverride;
@property (nonatomic, retain) NSString *_bodyOverride;
@end
