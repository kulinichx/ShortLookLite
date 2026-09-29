// Douyin (抖音) contact photos for ShortLook Reborn (RootHide). No original plugin exists.
// Douyin's push payload carries the sender avatar in apns_avatar_arg.avatar_url for every
// message type. "attachment" is the shared video's cover and the conversation icon iOS
// attaches is only the app icon, so neither is used.
#import "SLPluginSupport.h"

@interface DouyinContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

// Fallback: first http(s) URL under a key that names an avatar, in case the field moves.
static NSString *DYFindAvatarURL(id object, NSUInteger depth) {
	if (depth > 5) return nil;
	if ([object isKindOfClass:[NSString class]] && [(NSString *)object hasPrefix:@"{"]) {
		object = [NSJSONSerialization JSONObjectWithData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
	}
	if ([object isKindOfClass:[NSArray class]]) {
		for (id item in (NSArray *)object) {
			NSString *found = DYFindAvatarURL(item, depth + 1);
			if (found) return found;
		}
		return nil;
	}
	if (![object isKindOfClass:[NSDictionary class]]) return nil;
	NSDictionary *dictionary = object;
	for (id key in dictionary) {
		if (![[[key description] lowercaseString] containsString:@"avatar"]) continue;
		NSString *string = SLPayloadString(dictionary, [key description]);
		if (SLWebURL(string)) return string;
	}
	for (id key in dictionary) {
		NSString *found = DYFindAvatarURL(dictionary[key], depth + 1);
		if (found) return found;
	}
	return nil;
}

@implementation DouyinContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSDictionary *userInfo = [notification applicationUserInfo];
	if (![userInfo isKindOfClass:[NSDictionary class]]) return nil;

	NSString *url = SLPayloadString(userInfo, @"apns_avatar_arg.avatar_url");
	if (!SLWebURL(url)) url = DYFindAvatarURL(userInfo, 0);
	if (!SLWebURL(url)) return nil;
	return SLDownloadOffer([@"douyin:" stringByAppendingString:url], SLWebURL(url));
}

@end
