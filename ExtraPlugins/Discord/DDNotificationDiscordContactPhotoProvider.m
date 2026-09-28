#import "SLPluginSupport.h"

@interface DDNotificationDiscordContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

@implementation DDNotificationDiscordContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	// Original (Dynastic 1.0.1) sent user_id to https://discord-api.dynastic.co/avatar/<id>, which is gone.
	// Discord's push payload carries the sender's avatar hash next to user_id, so build the CDN URL directly.
	NSDictionary *userInfo = notification.applicationUserInfo;
	NSString *userID = SLPayloadString(userInfo, @"user_id");
	if (!userID || [userID rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound) return nil;
	NSString *avatarHash = SLPayloadString(userInfo, @"user_avatar");
	// Hashes are hex, animated ones start with "a_" (the .png URL gives their first frame).
	NSRegularExpression *hashPattern = [NSRegularExpression regularExpressionWithPattern:@"^(a_)?[A-Za-z0-9]+$" options:0 error:nil];
	if (avatarHash && [hashPattern firstMatchInString:avatarHash options:0 range:NSMakeRange(0, avatarHash.length)]) {
		NSString *url = [NSString stringWithFormat:@"https://cdn.discordapp.com/avatars/%@/%@.png?size=256", userID, avatarHash];
		return SLDownloadOffer(url, SLWebURL(url));
	}
	// No custom avatar: Discord shows a default avatar, (user_id >> 22) % 6, or discriminator % 5 for legacy #0000 users.
	unsigned long long index = (strtoull(userID.UTF8String, NULL, 10) >> 22) % 6;
	NSString *discriminator = SLPayloadString(userInfo, @"user_discriminator");
	if (discriminator.integerValue > 0) index = (unsigned long long)discriminator.integerValue % 5;
	NSString *url = [NSString stringWithFormat:@"https://cdn.discordapp.com/embed/avatars/%llu.png", index];
	return SLDownloadOffer(url, SLWebURL(url));
}

@end
