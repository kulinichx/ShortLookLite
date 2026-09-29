// Douyin (抖音) contact photos for ShortLook Reborn — diagnostic build 1.0.0~diag.1.
// No original plugin exists; the lookup mirrors the TikTok plugin (image URL in the push payload)
// and falls back to the conversation image iOS attaches to communication notifications.
// Every notification's payload layout is written to /var/mobile/Library/Caches/ShortLook/Douyin.log
// so the real field names can be confirmed on device.
#import "SLPluginSupport.h"
#import <UIKit/UIKit.h>

@interface NCNotificationRequest : NSObject
- (id)content;
@end

@interface DouyinContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

static void DYLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void DYLog(NSString *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	NSLog(@"[ShortLook-Douyin] %@", message);
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ queue = dispatch_queue_create("shortlook.plugin.Douyin.log", DISPATCH_QUEUE_SERIAL); });
	NSDate *date = [NSDate date];
	dispatch_async(queue, ^{
		NSString *directory = @"/var/mobile/Library/Caches/ShortLook";
		[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *path = [directory stringByAppendingPathComponent:@"Douyin.log"];
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
		if (attributes && attributes.fileSize > 1024 * 1024) [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		NSString *line = [NSString stringWithFormat:@"%@ %@\n", date, message];
		FILE *file = fopen(path.fileSystemRepresentation, "a");
		if (!file) return;
		fputs(line.UTF8String, file);
		fclose(file);
	});
}

__attribute__((constructor)) static void DYLoaded(void) {
	DYLog(@"插件已加载（进程 %@）", [NSProcessInfo processInfo].processName);
}

static id DYKV(id object, NSString *key) {
	if (!object || !key) return nil;
	@try {
		return [object valueForKey:key];
	} @catch (__unused NSException *exception) {
		return nil;
	}
}

static NSString *DYShort(id value) {
	if (!value) return @"(无)";
	if ([value isKindOfClass:[UIImage class]]) {
		UIImage *image = value;
		return [NSString stringWithFormat:@"UIImage %.0fx%.0f@%.0fx", image.size.width, image.size.height, image.scale];
	}
	NSString *text = [value isKindOfClass:[NSString class]] ? value : [NSString stringWithFormat:@"%@ %@", NSStringFromClass([value class]), value];
	return text.length > 160 ? [[text substringToIndex:160] stringByAppendingString:@"…"] : text;
}

// Flatten the payload into "a.b.c = value" lines (depth-limited) for the log.
static void DYDump(id object, NSString *prefix, NSUInteger depth, NSMutableArray<NSString *> *lines) {
	if (lines.count > 80) return;
	if ([object isKindOfClass:[NSDictionary class]] && depth < 5) {
		for (id key in [(NSDictionary *)object allKeys]) {
			NSString *name = [key description];
			DYDump(((NSDictionary *)object)[key], prefix.length ? [NSString stringWithFormat:@"%@.%@", prefix, name] : name, depth + 1, lines);
		}
	} else if ([object isKindOfClass:[NSArray class]] && depth < 5) {
		NSArray *array = object;
		[lines addObject:[NSString stringWithFormat:@"%@ = 数组(%lu)", prefix, (unsigned long)array.count]];
		if (array.count) DYDump(array.firstObject, [prefix stringByAppendingString:@"[0]"], depth + 1, lines);
	} else if ([object isKindOfClass:[NSString class]] && [(NSString *)object hasPrefix:@"{"]) {
		id parsed = [NSJSONSerialization JSONObjectWithData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
		if ([parsed isKindOfClass:[NSDictionary class]] && depth < 5) DYDump(parsed, [prefix stringByAppendingString:@"(json)"], depth + 1, lines);
		else [lines addObject:[NSString stringWithFormat:@"%@ = %@", prefix, DYShort(object)]];
	} else {
		[lines addObject:[NSString stringWithFormat:@"%@ = %@", prefix, DYShort(object)]];
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
	DYLog(@"通信通知：communicationContext=%@ sender=%@", DYShort(context), DYShort(DYKV(DYKV(context, @"sender"), @"displayName")));
	DYLog(@"通信通知：content.icons=%@", DYShort(icons));
	if (!context) return nil;
	id icon = [icons isKindOfClass:[NSArray class]] ? [(NSArray *)icons firstObject] : DYKV(content, @"icon");
	return [icon isKindOfClass:[UIImage class]] ? icon : nil;
}

@implementation DouyinContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSDictionary *userInfo = [notification applicationUserInfo];
	if (![userInfo isKindOfClass:[NSDictionary class]]) userInfo = nil;

	NSMutableArray<NSString *> *lines = [NSMutableArray array];
	DYDump(userInfo, @"", 0, lines);
	DYLog(@"收到抖音通知，userInfo 共 %lu 项：\n  %@", (unsigned long)lines.count, [lines componentsJoinedByString:@"\n  "]);

	// 1. Image URL in the push payload (TikTok uses "attachment").
	NSString *url = SLPayloadString(userInfo, @"attachment") ?: DYFindImageURL(userInfo, 0);
	if (SLWebURL(url)) {
		DYLog(@"使用推送里的图片地址：%@", DYShort(url));
		return SLDownloadOffer([@"douyin:" stringByAppendingString:url], SLWebURL(url));
	}

	// 2. Conversation image attached by iOS (communication notifications).
	UIImage *image = DYConversationImage(notification.request);
	if (image) {
		DYLog(@"使用通知自带的会话图片（%@）", DYShort(image));
		NSString *identifier = SLPayloadString(userInfo, @"from_uid") ?: SLPayloadString(userInfo, @"conversation_id") ?: [[NSUUID UUID] UUIDString];
		DDNotificationContactPhotoPromiseOffer *offer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"douyin-conv:" stringByAppendingString:identifier]];
		[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
			[promise resolveWithImage:image];
		}];
		return offer;
	}

	DYLog(@"没有找到头像，交回 ShortLook（显示应用图标）");
	return nil;
}

@end
