#import "SLPluginSupport.h"

@interface DDNotificationTwitterContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

@implementation DDNotificationTwitterContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	// Original (Dynastic 1.0.2): users.sender.profile_image_url with "_normal" removed for the full-size image.
	NSString *profileImage = SLPayloadString(notification.applicationUserInfo, @"users.sender.profile_image_url");
	if (!profileImage) return nil;
	NSString *fullSize = [profileImage stringByReplacingOccurrencesOfString:@"_normal" withString:@""];
	return SLDownloadOffer(fullSize, SLWebURL(fullSize));
}

@end
