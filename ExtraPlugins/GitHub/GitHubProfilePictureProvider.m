#import "SLPluginSupport.h"

@interface GitHubProfilePictureProvider : NSObject <DDNotificationContactPhotoProviding>
@end

@implementation GitHubProfilePictureProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	// Original (Marco Roth 1.0.0): first word of aps.alert.title, "@" removed, then github.com/<name>.png.
	// Titles are often "owner/repo", so use the owner in that case, and only accept valid GitHub logins.
	NSString *title = SLPayloadString(notification.applicationUserInfo, @"aps.alert.title");
	if (!title) return nil;
	NSString *username = [[title componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] firstObject];
	username = [username stringByReplacingOccurrencesOfString:@"@" withString:@""];
	username = [[username componentsSeparatedByString:@"/"] firstObject];
	NSRegularExpression *login = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$" options:0 error:nil];
	if (!username.length || ![login firstMatchInString:username options:0 range:NSMakeRange(0, username.length)]) return nil;
	NSString *url = [NSString stringWithFormat:@"https://github.com/%@.png", username];
	return SLDownloadOffer(url, SLWebURL(url));
}

@end
