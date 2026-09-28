#import "SLPluginSupport.h"

@interface TikTokContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

@implementation TikTokContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	// Original (JeffResc 1.0.0): top-level "attachment".
	NSString *attachment = SLPayloadString(notification.applicationUserInfo, @"attachment");
	return SLDownloadOffer(attachment, SLWebURL(attachment));
}

@end
