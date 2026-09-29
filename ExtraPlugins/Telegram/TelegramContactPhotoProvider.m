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
#import <sqlite3.h>
#import "TGSFolderFinder.h"
#import "TGSInitialsPictureGenerator.h"

@interface NCNotificationRequest : NSObject
- (NSString *)threadIdentifier;
- (NSString *)sectionIdentifier;
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

// Official Telegram or Swiftgram (same data layout). The AppGroup of the app that sent the
// notification is tried first (a leftover official-Telegram folder must not win for Swiftgram).
static NSString *TGSSharedFolder(NSString *bundleIdentifier) {
	NSArray *groups = [bundleIdentifier isEqualToString:@"app.swiftgram.ios"]
		? @[@"group.app.swiftgram.ios", @"group.ph.telegra.Telegraph"]
		: @[@"group.ph.telegra.Telegraph", @"group.app.swiftgram.ios"];
	for (NSString *group in groups) {
		NSString *folder = [TGSFolderFinder findSharedFolder:group];
		if (folder) {
			PLog(@"使用 AppGroup %@", group);
			return folder;
		}
	}
	return nil;
}

// Postbox peer table (t2, key = PeerId.toInt64()). The peer's "ph" array holds
// TelegramMediaImageRepresentation objects whose resource has d (datacenter), p (photo id), s (size spec).
// Downloaded files are media/telegram-peer-photo-size-<d>-<p>-<s>-0-0; the biggest existing one wins.
static UIImage *TGSPeerPhotoFromDatabase(NSString *sharedFolder, NSString *accountID, NSString *peerID) {
	if (!sharedFolder || !TGSIsDigits(peerID)) return nil;
	NSString *dataFolder = [sharedFolder stringByAppendingPathComponent:@"telegram-data"];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSMutableArray *accounts = [NSMutableArray array];
	if (TGSIsDigits(accountID)) [accounts addObject:[@"account-" stringByAppendingString:accountID]];
	for (NSString *entry in [manager contentsOfDirectoryAtPath:dataFolder error:nil]) {
		if ([entry hasPrefix:@"account-"] && ![accounts containsObject:entry]) [accounts addObject:entry];
	}
	sqlite3_int64 key = strtoll(peerID.UTF8String, NULL, 10);
	for (NSString *account in accounts) {
		NSString *postbox = [[dataFolder stringByAppendingPathComponent:account] stringByAppendingPathComponent:@"postbox"];
		NSString *dbPath = [postbox stringByAppendingPathComponent:@"db/db_sqlite"];
		if (![manager fileExistsAtPath:dbPath]) continue;
		sqlite3 *db = NULL;
		if (sqlite3_open_v2(dbPath.fileSystemRepresentation, &db, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) {
			PLog(@"数据库打不开 %@", account);
			if (db) sqlite3_close(db);
			continue;
		}
		sqlite3_busy_timeout(db, 300);
		NSData *value = nil;
		sqlite3_stmt *statement = NULL;
		if (sqlite3_prepare_v2(db, "SELECT value FROM t2 WHERE key = ?", -1, &statement, NULL) == SQLITE_OK) {
			sqlite3_bind_int64(statement, 1, key);
			if (sqlite3_step(statement) == SQLITE_ROW) {
				const void *bytes = sqlite3_column_blob(statement, 0);
				int length = sqlite3_column_bytes(statement, 0);
				if (bytes && length > 0) value = [NSData dataWithBytes:bytes length:length];
			}
		}
		if (statement) sqlite3_finalize(statement);
		sqlite3_close(db);
		if (!value) continue;

		const uint8_t *b = value.bytes;
		NSUInteger n = value.length;
		NSData *marker = [NSData dataWithBytes:"\x02ph\x08" length:4];
		NSRange found = [value rangeOfData:marker options:0 range:NSMakeRange(0, n)];
		if (found.location == NSNotFound || NSMaxRange(found) + 4 > n) {
			PLog(@"群/用户 %@ 在 %@ 里没有头像记录", peerID, account);
			return nil;
		}
		NSUInteger offset = NSMaxRange(found);
		int32_t count;
		memcpy(&count, b + offset, 4);
		offset += 4;
		NSString *best = nil;
		int32_t bestSpec = -1;
		for (int32_t i = 0; i < count && offset + 8 <= n; i++) {
			int32_t objectLength;
			memcpy(&objectLength, b + offset + 4, 4);
			NSUInteger start = offset + 8;
			if (objectLength < 0 || start + (NSUInteger)objectLength > n) break;
			offset = start + objectLength;
			int32_t dc = -1, spec = -1;
			int64_t photoID = 0;
			for (NSUInteger j = start; j + 3 <= offset; j++) {
				if (b[j] != 0x01) continue;
				if (b[j + 1] == 'd' && b[j + 2] == 0x00 && j + 7 <= offset && dc < 0) memcpy(&dc, b + j + 3, 4);
				else if (b[j + 1] == 'p' && b[j + 2] == 0x01 && j + 11 <= offset && !photoID) memcpy(&photoID, b + j + 3, 8);
				else if (b[j + 1] == 's' && b[j + 2] == 0x00 && j + 7 <= offset && spec < 0) memcpy(&spec, b + j + 3, 4);
			}
			if (dc < 0 || !photoID || spec < 0 || spec <= bestSpec) continue;
			NSString *file = [NSString stringWithFormat:@"telegram-peer-photo-size-%d-%lld-%d-0-0", dc, photoID, spec];
			NSString *path = [[postbox stringByAppendingPathComponent:@"media"] stringByAppendingPathComponent:file];
			BOOL exists = [manager fileExistsAtPath:path];
			PLog(@"数据库头像 %@：%@", file, exists ? @"文件存在" : @"没下载");
			if (exists) {
				best = path;
				bestSpec = spec;
			}
		}
		UIImage *image = best ? [UIImage imageWithContentsOfFile:best] : nil;
		if (image) PLog(@"用数据库头像（%@）", TGSDescribe(image));
		return image;
	}
	return nil;
}

static UIImage *TGSPhotoForKey(NSString *folderKey, NSString *bundleIdentifier) {
	NSString *sharedFolder = TGSSharedFolder(bundleIdentifier);
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
	NSString *accountID = TGSString(userInfo[@"accountId"]);
	NSString *bundleIdentifier = [request respondsToSelector:@selector(sectionIdentifier)] ? TGSString([request sectionIdentifier]) : nil;
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
		NSString *groupKey = TGSString(userInfo[@"chat_id"]) ?: TGSString(userInfo[@"channel_id"]) ?: threadIdentifier ?: @"group";
		DDNotificationContactPhotoPromiseOffer *groupOffer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"telegram-group:" stringByAppendingString:groupKey]];
		[groupOffer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
			UIImage *image = TGSPeerPhotoFromDatabase(TGSSharedFolder(bundleIdentifier), accountID, peerID);
			if (!image && conversationImage) {
				PLog(@"群组/频道消息，使用通知自带的会话图片（%@）", TGSDescribe(conversationImage));
				image = conversationImage;
			}
			if (image) [promise resolveWithImage:image];
			else {
				PLog(@"群组/频道消息，没有可用头像，交回 ShortLook");
				[promise reject];
			}
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
		UIImage *image = TGSPhotoForKey(folderKey, bundleIdentifier);
		if (!image) image = TGSPeerPhotoFromDatabase(TGSSharedFolder(bundleIdentifier), accountID, folderKey);
		if (image) [promise resolveWithImage:image];
		else {
			PLog(@"没有可用头像，交回 ShortLook（显示应用图标）");
			[promise reject];
		}
	}];
	return offer;
}

@end
