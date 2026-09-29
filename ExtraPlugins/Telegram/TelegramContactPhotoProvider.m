// Telegram Contact Photos for ShortLook, by RedenticDev (1.1.0). Reborn port:
// - same lookup as the original (HD avatar from data.json, then avatar.png, then initials);
// - the file work runs inside the promise (off SpringBoard's main thread) and the AppGroup path is cached;
// - an unreadable image rejects the promise instead of handing ShortLook a nil image;
// - payload / JSON values are type-checked.
// reborn.2:
// - Telegram names the spotlight folders p:<PeerId.toInt64()>. For user IDs >= 2^32 (newer accounts)
//   that is NOT the plain user ID: high 32 bits are shifted left by 35. The folder name is now taken
//   from userInfo["peerId"] (exactly that value) or computed from the plain ID.
// - avatarSourcePath may be absolute (Telegram stores it unchanged when it is outside the AppGroup).
// - diagnostic log: /var/mobile/Library/Caches/ShortLook/Telegram.log
// reborn.3 (diagnostic):
// - groups / channels: log the notification's communication context and content icons, and use the
//   system-provided conversation image (content.icons, only when a communication context exists) if any.
//   Private chats keep the original lookup.
#import "SLPluginSupport.h"
#import <UIKit/UIKit.h>
#import "TGSFolderFinder.h"
#import "TGSInitialsPictureGenerator.h"

@interface NCNotificationRequest : NSObject
- (NSString *)threadIdentifier;
- (id)content;
@end

@interface TelegramContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

static void PLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void PLog(NSString *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	NSLog(@"[ShortLook-Telegram] %@", message);
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ queue = dispatch_queue_create("shortlook.plugin.Telegram.log", DISPATCH_QUEUE_SERIAL); });
	NSDate *date = [NSDate date];
	dispatch_async(queue, ^{
		NSString *directory = @"/var/mobile/Library/Caches/ShortLook";
		[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *path = [directory stringByAppendingPathComponent:@"Telegram.log"];
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
		if (attributes && attributes.fileSize > 1024 * 1024) [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		NSString *line = [NSString stringWithFormat:@"%@ %@\n", date, message];
		FILE *file = fopen(path.fileSystemRepresentation, "a");
		if (!file) return;
		fputs(line.UTF8String, file);
		fclose(file);
	});
}

__attribute__((constructor)) static void TGSLoaded(void) {
	PLog(@"插件已加载（进程 %@）", [NSProcessInfo processInfo].processName);
}

static NSString *TGSString(id value) {
	if ([value isKindOfClass:[NSNumber class]]) value = [(NSNumber *)value stringValue];
	return [value isKindOfClass:[NSString class]] && [(NSString *)value length] ? value : nil;
}

static BOOL TGSIsDigits(NSString *string) {
	return string.length && [string rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound;
}

static id TGSKV(id object, NSString *key) {
	if (!object || !key) return nil;
	@try {
		return [object valueForKey:key];
	} @catch (__unused NSException *exception) {
		return nil;
	}
}

static NSString *TGSDescribe(id value) {
	if (!value) return @"(无)";
	if ([value isKindOfClass:[UIImage class]]) {
		UIImage *image = value;
		return [NSString stringWithFormat:@"UIImage %.0fx%.0f@%.0fx", image.size.width, image.size.height, image.scale];
	}
	NSString *text = [NSString stringWithFormat:@"%@ %@", NSStringFromClass([value class]), value];
	return text.length > 300 ? [[text substringToIndex:300] stringByAppendingString:@"…"] : text;
}

// Communication notifications (INSendMessageIntent): iOS puts the conversation image into content.icons.
static UIImage *TGSConversationImage(NCNotificationRequest *request) {
	id content = [request respondsToSelector:@selector(content)] ? [request content] : nil;
	id context = TGSKV(content, @"communicationContext");
	id sender = TGSKV(context, @"sender");
	PLog(@"群诊断：communicationContext=%@", TGSDescribe(context));
	PLog(@"群诊断：displayName=%@ identifier=%@ recipients=%@", TGSDescribe(TGSKV(context, @"displayName")),
	     TGSDescribe(TGSKV(context, @"identifier")), TGSDescribe(TGSKV(context, @"recipients")));
	PLog(@"群诊断：sender=%@ sender.displayName=%@", TGSDescribe(sender), TGSDescribe(TGSKV(sender, @"displayName")));
	id icons = TGSKV(content, @"icons");
	PLog(@"群诊断：content.icons=%@ content.icon=%@", TGSDescribe(icons), TGSDescribe(TGSKV(content, @"icon")));
	if (!context) return nil;
	id icon = [icons isKindOfClass:[NSArray class]] ? [(NSArray *)icons firstObject] : TGSKV(content, @"icon");

	// 1) The original file behind contentURL (intents-remote-image-proxy:?proxyIdentifier=file%253A...).
	id contentURL = TGSKV(context, @"contentURL");
	NSString *urlString = [contentURL isKindOfClass:[NSURL class]] ? [(NSURL *)contentURL absoluteString] : TGSString(contentURL);
	PLog(@"群诊断：contentURL=%@", urlString ?: @"(无)");
	NSRange range = [urlString rangeOfString:@"proxyIdentifier="];
	if (range.location != NSNotFound) {
		NSString *value = [urlString substringFromIndex:NSMaxRange(range)];
		NSRange amp = [value rangeOfString:@"&"];
		if (amp.location != NSNotFound) value = [value substringToIndex:amp.location];
		for (int i = 0; i < 4 && ![value hasPrefix:@"file:"] && ![value hasPrefix:@"/"]; i++) {
			NSString *decoded = value.stringByRemovingPercentEncoding;
			if (!decoded || [decoded isEqualToString:value]) break;
			value = decoded;
		}
		NSString *filePath = [value hasPrefix:@"file:"] ? [NSURL URLWithString:value].path : value;
		if (!filePath && [value hasPrefix:@"file://"]) filePath = [[value substringFromIndex:7] stringByRemovingPercentEncoding];
		UIImage *fileImage = filePath ? [UIImage imageWithContentsOfFile:filePath] : nil;
		PLog(@"群诊断：原图 %@：%@", filePath ?: value, fileImage ? TGSDescribe(fileImage) : @"读不到");
		if (fileImage) return fileImage;
	}

	// 2) Fallback: content.icons may be a lazy image with no bitmap; redraw it into a real one.
	if (![icon isKindOfClass:[UIImage class]]) return nil;
	UIImage *iconImage = icon;
	PLog(@"群诊断：icon CGImage=%@ CIImage=%@", iconImage.CGImage ? @"有" : @"无", iconImage.CIImage ? @"有" : @"无");
	if (iconImage.size.width <= 0 || iconImage.size.height <= 0) return nil;
	UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
	format.scale = iconImage.scale > 0 ? iconImage.scale : 3;
	UIImage *redrawn = [[[UIGraphicsImageRenderer alloc] initWithSize:iconImage.size format:format] imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
		[iconImage drawInRect:CGRectMake(0, 0, iconImage.size.width, iconImage.size.height)];
	}];
	return redrawn.CGImage ? redrawn : iconImage;
}

// Plain user ID -> Telegram's PeerId.toInt64() for namespace CloudUser (0):
// (idHigh32 << 35) | idLow32. Identical to the plain ID below 2^32.
static NSString *TGSFolderKeyForUserID(NSString *userID) {
	if (!TGSIsDigits(userID)) return nil;
	unsigned long long value = strtoull(userID.UTF8String, NULL, 10);
	unsigned long long key = ((value >> 32) << 35) | (value & 0xffffffffULL);
	return [NSString stringWithFormat:@"%llu", key];
}

// Official Telegram or Swiftgram (same data layout); the AppGroup that worked is remembered.
static NSString *TGSSharedFolder(void) {
	static NSString *workingGroup = nil;
	if (workingGroup) {
		NSString *folder = [TGSFolderFinder findSharedFolder:workingGroup];
		if (folder) return folder;
	}
	for (NSString *group in @[@"group.ph.telegra.Telegraph", @"group.app.swiftgram.ios"]) {
		NSString *folder = [TGSFolderFinder findSharedFolder:group];
		if (folder) {
			workingGroup = group;
			PLog(@"使用 AppGroup %@", group);
			return folder;
		}
	}
	return nil;
}

static UIImage *TGSPhotoForKey(NSString *folderKey) {
	NSString *sharedFolder = TGSSharedFolder();
	if (!sharedFolder) {
		PLog(@"找不到 Telegram / Swiftgram 的 AppGroup");
		return nil;
	}
	NSString *spotlightFolder = [sharedFolder stringByAppendingPathComponent:@"telegram-data/accounts-metadata/spotlight"];
	NSString *conversationFolder = [spotlightFolder stringByAppendingPathComponent:[@"p:" stringByAppendingString:folderKey]];
	NSFileManager *manager = [NSFileManager defaultManager];
	if (![manager fileExistsAtPath:conversationFolder]) {
		NSArray *entries = [manager contentsOfDirectoryAtPath:spotlightFolder error:nil];
		PLog(@"没有 %@（spotlight 目录共 %lu 项%@）。Telegram 只给「联系人」写这个目录", conversationFolder.lastPathComponent,
		     (unsigned long)entries.count, entries ? @"" : @"，目录不存在");
	}
	NSString *firstName = nil;
	NSString *lastName = nil;

	// HD profile picture
	NSData *jsonData = [NSData dataWithContentsOfFile:[conversationFolder stringByAppendingPathComponent:@"data.json"]];
	if (jsonData) {
		id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
		if ([parsed isKindOfClass:[NSDictionary class]]) {
			NSString *avatarSourcePath = TGSString(parsed[@"avatarSourcePath"]);
			if (avatarSourcePath) {
				NSString *path = [avatarSourcePath hasPrefix:@"/"] ? avatarSourcePath : [sharedFolder stringByAppendingPathComponent:avatarSourcePath];
				UIImage *image = [UIImage imageWithContentsOfFile:path];
				PLog(@"data.json 头像 %@：%@", avatarSourcePath, image ? @"读到" : @"读不到");
				if (image) return image;
			}
			firstName = TGSString(parsed[@"firstName"]);
			lastName = TGSString(parsed[@"lastName"]);
		}
	}

	// SD profile picture
	UIImage *image = [UIImage imageWithContentsOfFile:[conversationFolder stringByAppendingPathComponent:@"avatar.png"]];
	if (image) {
		PLog(@"用 avatar.png");
		return image;
	}

	// Initials, like Telegram does for contacts without a photo
	if (firstName) {
		PLog(@"没有头像图片，用首字母");
		return [TGSInitialsPictureGenerator generatePictureWithFirstLetter:[[firstName uppercaseString] characterAtIndex:0]
		                                                      secondLetter:lastName.length ? [[lastName uppercaseString] characterAtIndex:0] : '\0'];
	}
	return nil;
}

@implementation TelegramContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NCNotificationRequest *request = notification.request;
	NSDictionary *userInfo = [notification applicationUserInfo];
	if (![userInfo isKindOfClass:[NSDictionary class]]) userInfo = nil;
	NSString *threadIdentifier = [request respondsToSelector:@selector(threadIdentifier)] ? TGSString([request threadIdentifier]) : nil;
	NSString *fromID = TGSString(userInfo[@"from_id"]);
	NSString *peerID = TGSString(userInfo[@"peerId"]);
	PLog(@"收到 Telegram 通知 thread=%@ from_id=%@ peerId=%@ userInfo 键=%@", threadIdentifier ?: @"(无)", fromID ?: @"(无)",
	     peerID ?: @"(无)", userInfo.allKeys);

	// Locked app / secret chat: Telegram gives no sender info. Groups and channels are unsupported (as in the original).
	NSString *lowercase = threadIdentifier.lowercaseString;
	if ([lowercase isEqualToString:@"locked"] || [lowercase isEqualToString:@"secret"]) {
		PLog(@"锁定或私密聊天，交回 ShortLook");
		return nil;
	}
	if (userInfo[@"chat_id"] || userInfo[@"channel_id"] || [threadIdentifier hasPrefix:@"-"]) {
		UIImage *conversationImage = TGSConversationImage(request);
		if (!conversationImage) {
			PLog(@"群组/频道消息，通知里没有会话图片，交回 ShortLook");
			return nil;
		}
		NSString *groupKey = TGSString(userInfo[@"chat_id"]) ?: TGSString(userInfo[@"channel_id"]) ?: threadIdentifier ?: @"group";
		PLog(@"群组/频道消息，使用通知自带的会话图片（%@）", TGSDescribe(conversationImage));
		DDNotificationContactPhotoPromiseOffer *groupOffer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"telegram-group:" stringByAppendingString:groupKey]];
		[groupOffer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
			[promise resolveWithImage:conversationImage];
		}];
		return groupOffer;
	}

	// Folder key = PeerId.toInt64(). userInfo["peerId"] is exactly that for private chats.
	NSString *folderKey = nil;
	if (fromID && TGSIsDigits(peerID)) folderKey = peerID;
	if (!folderKey) folderKey = TGSFolderKeyForUserID(fromID);
	if (!folderKey) folderKey = TGSFolderKeyForUserID(threadIdentifier);
	if (!folderKey) {
		PLog(@"拿不到用户 ID，交回 ShortLook");
		return nil;
	}

	DDNotificationContactPhotoPromiseOffer *offer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"telegram:" stringByAppendingString:folderKey]];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		UIImage *image = TGSPhotoForKey(folderKey);
		if (image) [promise resolveWithImage:image];
		else {
			PLog(@"没有可用头像，交回 ShortLook（显示应用图标）");
			[promise reject];
		}
	}];
	return offer;
}

@end
