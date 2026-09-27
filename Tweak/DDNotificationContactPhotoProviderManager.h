#import "DDNotificationProtocols.h"
#import "DDNotificationContactPhotoPromiseOffer.h"

@interface DDNotificationContactPhotoProviderManager : NSObject
+ (instancetype)sharedManager;
- (void)registerProvider:(Class)providerClass;
- (void)registerProvider:(Class)providerClass forBundleIdentifier:(NSString *)bundleIdentifier;
- (NSArray *)providersForNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(NSObject<DDNotificationDisplayable> *)notification;
- (BOOL)getContactPhotoForOffer:(DDNotificationContactPhotoPromiseOffer *)offer withSenderIdentifier:(NSString *)senderIdentifier completionHandler:(void (^)(UIImage *image, DDNotificationContactPhotoSettings *settings))completionHandler;
- (NSString *)contactPhotoIdentifierForUserNotification:(DDUserNotification *)notification;
@end
