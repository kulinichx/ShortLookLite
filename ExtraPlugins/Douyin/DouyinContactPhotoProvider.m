// Douyin (抖音) contact photos for ShortLook Reborn (RootHide). No original plugin exists;
// the lookup mirrors the TikTok plugin (image URL in the push payload) and falls back to the
// conversation image iOS attaches to communication notifications.
#import "SLPluginSupport.h"
#import <UIKit/UIKit.h>

@interface NCNotificationRequest : NSObject
- (id)content;
@end

@interface DouyinContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

static id DYKV(id object, NSString *key) {
	if (!object || !key) return nil;
	@try {
		return [object valueForKey:key];
	} @catch (__unused NSException *exception) {
		return nil;
	}
}

// First http(s) image URL under a key that looks like an avatar / image field.
static NSString *DYFindImageURL(id object, NSUInteger depth) {
	if (depth > 5) return nil;
	if ([object isKindOfClass:[NSString class]] && [(NSString *)object hasPrefix:@"{"]) {
		object = [NSJSONSerialization JSONObjectWithData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
	}
	if ([object isKindOfClass:[NSArray class]]) {
		for (id item in (NSArray *)object) {
			NSString *found = DYFindImageURL(item, depth + 1);
			if (found) return found;
		}
		return nil;
	}
	if (![object isKindOfClass:[NSDictionary class]]) return nil;
	NSDictionary *dictionary = object;
	NSArray *hints = @[@"avatar", @"attachment", @"image", @"img", @"icon", @"pic", @"thumb", @"cover"];
	for (id key in dictionary) {
		NSString *name = [[key description] lowercaseString];
		BOOL hinted = NO;
		for (NSString *hint in hints) if ([name containsString:hint]) { hinted = YES; break; }
		id value = dictionary[key];
		if (hinted) {
			NSString *string = SLPayloadString(dictionary, [key description]);
			if (SLWebURL(string)) return string;
			if ([value isKindOfClass:[NSDictionary class]]) {
				NSString *nested = SLPayloadString(value, @"url_list") ?: SLPayloadString(value, @"url") ?: SLPayloadString(value, @"uri");
				if (SLWebURL(nested)) return nested;
			}
		}
	}
	for (id key in dictionary) {
		NSString *found = DYFindImageURL(dictionary[key], depth + 1);
		if (found) return found;
	}
	return nil;
}

static UIImage *DYConversationImage(NCNotificationRequest *request) {
	id content = [request respondsToSelector:@selector(content)] ? [request content] : nil;
	id context = DYKV(content, @"communicationContext");
	id icons = DYKV(content, @"icons");
	if (!context) return nil;
	id icon = [icons isKindOfClass:[NSArray class]] ? [(NSArray *)icons firstObject] : DYKV(content, @"icon");
	return [icon isKindOfClass:[UIImage class]] ? icon : nil;
}

@implementation DouyinContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSDictionary *userInfo = [notification applicationUserInfo];
	if (![userInfo isKindOfClass:[NSDictionary class]]) userInfo = nil;

	// 1. Image URL in the push payload (TikTok uses "attachment").
	NSString *url = SLPayloadString(userInfo, @"attachment") ?: DYFindImageURL(userInfo, 0);
	if (SLWebURL(url)) {
		return SLDownloadOffer([@"douyin:" stringByAppendingString:url], SLWebURL(url));
	}

	// 2. Conversation image attached by iOS (communication notifications).
	UIImage *image = DYConversationImage(notification.request);
	if (image) {
		NSString *identifier = SLPayloadString(userInfo, @"from_uid") ?: SLPayloadString(userInfo, @"conversation_id") ?: [[NSUUID UUID] UUIDString];
		DDNotificationContactPhotoPromiseOffer *offer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"douyin-conv:" stringByAppendingString:identifier]];
		[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
			[promise resolveWithImage:image];
		}];
		return offer;
	}

	return nil;
}

@end
