#import <Foundation/Foundation.h>

@class NCNotificationRequest;

@interface DDDemoNotificationManager : NSObject
+ (instancetype)sharedManager;
- (void)sendDemoNotification;
- (NCNotificationRequest *)notificationRequestForTitle:(NSString *)title content:(NSString *)content fromApplicationIdentifier:(NSString *)applicationIdentifier;
- (void)clearDemoNotifications;
- (NSString *)randomBundleIdentifier;
@end
