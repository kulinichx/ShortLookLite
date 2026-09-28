#import "SLPluginSupport.h"

@interface DDNotificationInstagramContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

@implementation DDNotificationInstagramContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	// Original (Dynastic 1.0.2): the profile picture URL is in the top-level "a" key.
	NSString *profileImage = SLPayloadString(notification.applicationUserInfo, @"a");
	return SLDownloadOffer(profileImage, SLWebURL(profileImage));
}

@end
