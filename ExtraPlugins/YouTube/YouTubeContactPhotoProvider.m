#import "SLPluginSupport.h"

@interface YouTubeContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

@implementation YouTubeContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	// Original (JeffResc 1.0.1): top-level "attachment-url-static" (the video thumbnail).
	NSString *thumbnail = SLPayloadString(notification.applicationUserInfo, @"attachment-url-static");
	return SLDownloadOffer(thumbnail, SLWebURL(thumbnail));
}

@end
