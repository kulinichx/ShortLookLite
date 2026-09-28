#import "SLPluginSupport.h"

@interface PinterestContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

@implementation PinterestContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	// Original (JeffResc 1.0.1): aps.alert.img.
	NSString *profileImage = SLPayloadString(notification.applicationUserInfo, @"aps.alert.img");
	return SLDownloadOffer(profileImage, SLWebURL(profileImage));
}

@end
