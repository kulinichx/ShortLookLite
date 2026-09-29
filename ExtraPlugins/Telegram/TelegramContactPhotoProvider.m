// Telegram Contact Photos for ShortLook, by RedenticDev (1.1.0). Reborn port (ShortLook Reborn, RootHide):
// - private chats: the original lookup (spotlight data.json HD avatar, then avatar.png, then initials);
//   the spotlight folder is p:<PeerId.toInt64()> (userInfo["peerId"], or computed from the plain user ID).
// - Swiftgram (app.swiftgram.ios) supported; the AppGroup of the sending app is used first.
// - groups / channels and non-contacts: the peer photo is looked up in the account's Postbox database;
//   groups fall back to the image attached to the communication notification.
// - all file / database work runs inside the promise, off SpringBoard's main thread.
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

// Communication notifications (INSendMessageIntent): iOS puts the conversation image into content.icons.
static UIImage *TGSConversationImage(NCNotificationRequest *request) {
	id content = [request respondsToSelector:@selector(content)] ? [request content] : nil;
	id context = TGSKV(content, @"communicationContext");
	id icons = TGSKV(content, @"icons");
	if (!context) return nil;
	id icon = [icons isKindOfClass:[NSArray class]] ? [(NSArray *)icons firstObject] : TGSKV(content, @"icon");

	// 1) The original file behind contentURL (intents-remote-image-proxy:?proxyIdentifier=file%253A...).
	id contentURL = TGSKV(context, @"contentURL");
	NSString *urlString = [contentURL isKindOfClass:[NSURL class]] ? [(NSURL *)contentURL absoluteString] : TGSString(contentURL);
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
		if (fileImage) return fileImage;
	}

	// 2) Fallback: content.icons may be a lazy image with no bitmap; redraw it into a real one.
	if (![icon isKindOfClass:[UIImage class]]) return nil;
	UIImage *iconImage = icon;
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
		if (folder) return folder;
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
		if (found.location == NSNotFound || NSMaxRange(found) + 4 > n) return nil;
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
			if ([manager fileExistsAtPath:path]) {
				best = path;
				bestSpec = spec;
			}
		}
		return best ? [UIImage imageWithContentsOfFile:best] : nil;
	}
	return nil;
}

static UIImage *TGSPhotoForKey(NSString *folderKey, NSString *bundleIdentifier) {
	NSString *sharedFolder = TGSSharedFolder(bundleIdentifier);
	if (!sharedFolder) return nil;
	NSString *spotlightFolder = [sharedFolder stringByAppendingPathComponent:@"telegram-data/accounts-metadata/spotlight"];
	NSString *conversationFolder = [spotlightFolder stringByAppendingPathComponent:[@"p:" stringByAppendingString:folderKey]];
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
				if (image) return image;
			}
			firstName = TGSString(parsed[@"firstName"]);
			lastName = TGSString(parsed[@"lastName"]);
		}
	}

	// SD profile picture
	UIImage *image = [UIImage imageWithContentsOfFile:[conversationFolder stringByAppendingPathComponent:@"avatar.png"]];
	if (image) return image;

	// Initials, like Telegram does for contacts without a photo
	if (firstName) {
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

	// Locked app / secret chat: Telegram gives no sender info.
	NSString *lowercase = threadIdentifier.lowercaseString;
	if ([lowercase isEqualToString:@"locked"] || [lowercase isEqualToString:@"secret"]) return nil;
	if (userInfo[@"chat_id"] || userInfo[@"channel_id"] || [threadIdentifier hasPrefix:@"-"]) {
		NSString *groupKey = TGSString(userInfo[@"chat_id"]) ?: TGSString(userInfo[@"channel_id"]) ?: threadIdentifier ?: @"group";
		DDNotificationContactPhotoPromiseOffer *groupOffer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"telegram-group:" stringByAppendingString:groupKey]];
		[groupOffer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
			UIImage *image = TGSPeerPhotoFromDatabase(TGSSharedFolder(bundleIdentifier), accountID, peerID);
			if (!image) image = TGSConversationImage(request);
			if (image) [promise resolveWithImage:image];
			else [promise reject];
		}];
		return groupOffer;
	}

	// Folder key = PeerId.toInt64(). userInfo["peerId"] is exactly that for private chats.
	NSString *folderKey = nil;
	if (fromID && TGSIsDigits(peerID)) folderKey = peerID;
	if (!folderKey) folderKey = TGSFolderKeyForUserID(fromID);
	if (!folderKey) folderKey = TGSFolderKeyForUserID(threadIdentifier);
	if (!folderKey) return nil;

	DDNotificationContactPhotoPromiseOffer *offer = [[NSClassFromString(@"DDNotificationContactPhotoPromiseOffer") alloc] initWithPhotoIdentifier:[@"telegram:" stringByAppendingString:folderKey]];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		UIImage *image = TGSPhotoForKey(folderKey, bundleIdentifier);
		if (!image) image = TGSPeerPhotoFromDatabase(TGSSharedFolder(bundleIdentifier), accountID, folderKey);
		if (image) [promise resolveWithImage:image];
		else [promise reject];
	}];
	return offer;
}

@end
