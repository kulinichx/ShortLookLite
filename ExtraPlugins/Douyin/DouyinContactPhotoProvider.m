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

// The payload links a 100x100 thumbnail; Douyin's CDN serves the same avatar at 1080x1080
// (capped at the uploaded size). Any failure falls back to the original link.
static NSURL *DYLargeAvatarURL(NSURL *url) {
	NSString *path = url.path;
	NSRange range = [path rangeOfString:@"/100x100/"];
	if (range.location == NSNotFound) return nil;
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	components.path = [path stringByReplacingCharactersInRange:range withString:@"/1080x1080/"];
	return components.URL;
}

static void DYLoadImage(NSURL *url, void (^completion)(UIImage *image)) {
	if (!url) { completion(nil); return; }
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:8];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
		UIImage *image = (!error && status == 200 && data.length) ? [UIImage imageWithData:data] : nil;
		completion(image);
	}] resume];
}

@implementation DouyinContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSDictionary *userInfo = [notification applicationUserInfo];
	if (![userInfo isKindOfClass:[NSDictionary class]]) return nil;

	NSString *url = SLPayloadString(userInfo, @"apns_avatar_arg.avatar_url");
	if (!SLWebURL(url)) url = DYFindAvatarURL(userInfo, 0);
	if (!SLWebURL(url)) return nil;
	NSURL *smallURL = SLWebURL(url);
	NSURL *largeURL = DYLargeAvatarURL(smallURL);
	if (!largeURL) return SLDownloadOffer([@"douyin:" stringByAppendingString:url], smallURL);

	DDNotificationContactPhotoPromiseOffer *offer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"douyin-hd:" stringByAppendingString:url]];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		DYLoadImage(largeURL, ^(UIImage *large) {
			if (large) { [promise resolveWithImage:large]; return; }
			DYLoadImage(smallURL, ^(UIImage *small) {
				if (small) [promise resolveWithImage:small];
				else [promise reject];
			});
		});
	}];
	return offer;
}

@end
