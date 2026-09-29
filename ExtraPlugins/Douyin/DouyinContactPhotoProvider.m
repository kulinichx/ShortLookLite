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

// First http(s) URL under a key that names the sender's avatar. Generic image keys
// (image / cover / thumb / attachment) are skipped: for shared videos they hold the video cover.
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
	NSArray *hints = @[@"avatar", @"head_img", @"headimg", @"portrait"];
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

// ===== TEMP DIAG (test/douyin-diag only, never merge) =====
// Logs payload structure only: key paths, value types, string lengths, URL host/path.
// Message text is never written. Output: /var/mobile/Library/Caches/ShortLook/douyin-diag.log
static NSString *const kDYDiagDir = @"/var/mobile/Library/Caches/ShortLook";
static void DYDiag(NSString *line) {
	[[NSFileManager defaultManager] createDirectoryAtPath:kDYDiagDir withIntermediateDirectories:YES attributes:nil error:nil];
	NSString *path = [kDYDiagDir stringByAppendingPathComponent:@"douyin-diag.log"];
	FILE *file = fopen(path.fileSystemRepresentation, "a");
	if (!file) return;
	fputs([line stringByAppendingString:@"\n"].UTF8String, file);
	fclose(file);
}
static void DYDiagDump(id object, NSString *keyPath, NSUInteger depth) {
	if (depth > 8) return;
	if ([object isKindOfClass:[NSString class]]) {
		NSString *string = object;
		if ([string hasPrefix:@"{"] || [string hasPrefix:@"["]) {
			id json = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
			if (json) { DYDiag([NSString stringWithFormat:@"  %@ = <JSON string>", keyPath]); DYDiagDump(json, keyPath, depth + 1); return; }
		}
		NSURL *url = SLWebURL(string);
		if (url) DYDiag([NSString stringWithFormat:@"  %@ = URL %@%@", keyPath, url.host, url.path.length > 90 ? [url.path substringToIndex:90] : url.path]);
		else DYDiag([NSString stringWithFormat:@"  %@ = string(len %lu)", keyPath, (unsigned long)string.length]);
		return;
	}
	if ([object isKindOfClass:[NSNumber class]]) { DYDiag([NSString stringWithFormat:@"  %@ = number", keyPath]); return; }
	if ([object isKindOfClass:[NSArray class]]) {
		NSArray *array = object;
		DYDiag([NSString stringWithFormat:@"  %@ = array(%lu)", keyPath, (unsigned long)array.count]);
		for (NSUInteger i = 0; i < MIN(array.count, (NSUInteger)5); i++) DYDiagDump(array[i], [NSString stringWithFormat:@"%@[%lu]", keyPath, (unsigned long)i], depth + 1);
		return;
	}
	if ([object isKindOfClass:[NSDictionary class]]) {
		for (id key in (NSDictionary *)object) DYDiagDump(((NSDictionary *)object)[key], [NSString stringWithFormat:@"%@.%@", keyPath, key], depth + 1);
		return;
	}
	DYDiag([NSString stringWithFormat:@"  %@ = <%@>", keyPath, object ? NSStringFromClass([object class]) : @"nil"]);
}
static void DYDiagNotification(DDUserNotification *notification, NSDictionary *userInfo) {
	@try {
		static NSUInteger counter = 0;
		NSUInteger index = ++counter;
		DYDiag([NSString stringWithFormat:@"==== %@ #%lu ====", [NSDate date], (unsigned long)index]);
		DYDiag(@"userInfo:");
		DYDiagDump(userInfo, @"userInfo", 0);
		id content = [notification.request respondsToSelector:@selector(content)] ? [notification.request content] : nil;
		id context = DYKV(content, @"communicationContext");
		DYDiag([NSString stringWithFormat:@"content=%@ communicationContext=%@", content ? NSStringFromClass([content class]) : @"nil", context ? NSStringFromClass([context class]) : @"nil"]);
		for (NSString *key in @[@"sender", @"recipients", @"contentURL", @"imageName", @"systemImage"]) {
			id value = DYKV(context, key);
			DYDiag([NSString stringWithFormat:@"  context.%@ = %@", key, value ? NSStringFromClass([value class]) : @"nil"]);
		}
		id sender = DYKV(context, @"sender");
		id senderImage = DYKV(sender, @"image");
		DYDiag([NSString stringWithFormat:@"  context.sender.image = %@", senderImage ? NSStringFromClass([senderImage class]) : @"nil"]);
		id icons = DYKV(content, @"icons");
		DYDiag([NSString stringWithFormat:@"content.icons = %@ count %lu", icons ? NSStringFromClass([icons class]) : @"nil", [icons isKindOfClass:[NSArray class]] ? (unsigned long)[(NSArray *)icons count] : 0UL]);
		NSUInteger iconIndex = 0;
		for (id icon in ([icons isKindOfClass:[NSArray class]] ? icons : @[])) {
			if (![icon isKindOfClass:[UIImage class]]) continue;
			UIImage *image = icon;
			DYDiag([NSString stringWithFormat:@"  icon[%lu] %.0fx%.0f @%.0fx", (unsigned long)iconIndex, image.size.width, image.size.height, image.scale]);
			[UIImagePNGRepresentation(image) writeToFile:[kDYDiagDir stringByAppendingPathComponent:[NSString stringWithFormat:@"douyin-%lu-icon%lu.png", (unsigned long)index, (unsigned long)iconIndex]] atomically:YES];
			iconIndex++;
		}
		id attachments = DYKV(content, @"attachments");
		DYDiag([NSString stringWithFormat:@"content.attachments count %lu", [attachments isKindOfClass:[NSArray class]] ? (unsigned long)[(NSArray *)attachments count] : 0UL]);
		for (id attachment in ([attachments isKindOfClass:[NSArray class]] ? attachments : @[])) {
			NSURL *fileURL = DYKV(attachment, @"URL");
			DYDiag([NSString stringWithFormat:@"  attachment %@ type=%@ file=%@", NSStringFromClass([attachment class]), DYKV(attachment, @"type") ?: @"?", [fileURL isKindOfClass:[NSURL class]] ? fileURL.lastPathComponent : @"?"]);
		}
		for (NSString *key in @[@"categoryIdentifier", @"threadIdentifier"]) {
			id value = DYKV(content, key);
			DYDiag([NSString stringWithFormat:@"content.%@ = %@", key, [value isKindOfClass:[NSString class]] ? value : @"nil"]);
		}
	} @catch (NSException *exception) {
		DYDiag([NSString stringWithFormat:@"diag exception %@", exception.name]);
	}
}
// ===== END TEMP DIAG =====

@implementation DouyinContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSDictionary *userInfo = [notification applicationUserInfo];
	if (![userInfo isKindOfClass:[NSDictionary class]]) userInfo = nil;
	DYDiagNotification(notification, userInfo);

	// 1. Conversation image attached by iOS (communication notifications): always the sender.
	UIImage *image = DYConversationImage(notification.request);
	if (image) {
		NSString *identifier = SLPayloadString(userInfo, @"from_uid") ?: SLPayloadString(userInfo, @"conversation_id") ?: [[NSUUID UUID] UUIDString];
		DDNotificationContactPhotoPromiseOffer *offer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"douyin-conv:" stringByAppendingString:identifier]];
		[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
			[promise resolveWithImage:image];
		}];
		return offer;
	}

	// 2. Avatar URL in the push payload.
	NSString *url = DYFindImageURL(userInfo, 0);
	if (SLWebURL(url)) {
		return SLDownloadOffer([@"douyin:" stringByAppendingString:url], SLWebURL(url));
	}

	return nil;
}

@end
