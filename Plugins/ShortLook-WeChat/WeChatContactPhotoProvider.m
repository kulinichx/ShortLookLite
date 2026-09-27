// WeChat contact photos for ShortLook (ShortLook Contact Photo Provider API v1).
// userInfo["u"] is the conversation userName (wxid_xxx / xxx@chatroom); the avatar URL
// is read from WeChat's local WCDB_Contact.sqlite (Friend.dbContactHeadImage).
#import "ShortLook-API.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#import <sqlite3.h>

static NSString *const kWeChatBundleIdentifier = @"com.tencent.xin";

@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
- (NSURL *)dataContainerURL;
@end

@interface LSApplicationRecord : NSObject
- (instancetype)initWithBundleIdentifier:(NSString *)identifier allowPlaceholder:(BOOL)allowPlaceholder error:(NSError **)error;
- (NSURL *)dataContainerURL;
@end

@interface WeChatContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

// Diagnostic log: /var/mobile/Library/Caches/ShortLook/WeChat.log
static void PLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void PLog(NSString *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	NSLog(@"[ShortLook-WeChat] %@", message);
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ queue = dispatch_queue_create("shortlook.plugin.WeChat.log", DISPATCH_QUEUE_SERIAL); });
	NSDate *date = [NSDate date];
	dispatch_async(queue, ^{
		NSString *directory = @"/var/mobile/Library/Caches/ShortLook";
		[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *path = [directory stringByAppendingPathComponent:@"WeChat.log"];
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
		if (attributes && attributes.fileSize > 1024 * 1024) [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		NSString *line = [NSString stringWithFormat:@"%@ %@\n", date, message];
		FILE *file = fopen(path.fileSystemRepresentation, "a");
		if (!file) return;
		fputs(line.UTF8String, file);
		fclose(file);
	});
}

__attribute__((constructor)) static void PLoaded(void) {
	PLog(@"插件已加载（进程 %@）", [NSProcessInfo processInfo].processName);
}

static NSString *WCMD5(NSString *string) {
	const char *bytes = string.UTF8String;
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5(bytes, (CC_LONG)strlen(bytes), digest);
	NSMutableString *out = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
	for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [out appendFormat:@"%02x", digest[i]];
	return out;
}

static NSString *WCString(id value) {
	if ([value isKindOfClass:[NSString class]]) return value;
	if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
	return nil;
}

static NSString *WCDocumentsPath(void) {
	NSURL *url = nil;
	Class proxyClass = objc_getClass("LSApplicationProxy");
	if ([proxyClass respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
		LSApplicationProxy *proxy = [proxyClass applicationProxyForIdentifier:kWeChatBundleIdentifier];
		if ([proxy respondsToSelector:@selector(dataContainerURL)]) url = [proxy dataContainerURL];
	}
	if (!url) {
		Class recordClass = objc_getClass("LSApplicationRecord");
		if ([recordClass instancesRespondToSelector:@selector(initWithBundleIdentifier:allowPlaceholder:error:)]) {
			LSApplicationRecord *record = [[recordClass alloc] initWithBundleIdentifier:kWeChatBundleIdentifier allowPlaceholder:NO error:nil];
			if ([record respondsToSelector:@selector(dataContainerURL)]) url = [record dataContainerURL];
		}
	}
	return url ? [url.path stringByAppendingPathComponent:@"Documents"] : nil;
}

// Current account first (LocalInfo.lst $objects[2] -> MD5 folder), then the rest by modification date.
static NSArray<NSString *> *WCDatabaseCandidates(void) {
	NSString *documents = WCDocumentsPath();
	PLog(@"微信 Documents：%@", documents ?: @"(找不到微信数据容器)");
	if (!documents) return @[];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableArray *candidates = [NSMutableArray array];

	NSDictionary *localInfo = [NSDictionary dictionaryWithContentsOfFile:[documents stringByAppendingPathComponent:@"LocalInfo.lst"]];
	NSArray *objects = [localInfo[@"$objects"] isKindOfClass:[NSArray class]] ? localInfo[@"$objects"] : nil;
	if (objects.count > 2 && [objects[2] isKindOfClass:[NSString class]]) {
		NSString *path = [NSString stringWithFormat:@"%@/%@/DB/WCDB_Contact.sqlite", documents, WCMD5(objects[2])];
		if ([fileManager fileExistsAtPath:path]) [candidates addObject:path];
	}

	NSMutableArray *others = [NSMutableArray array];
	for (NSString *name in [fileManager contentsOfDirectoryAtPath:documents error:nil]) {
		if (name.length != 32) continue;
		NSString *path = [NSString stringWithFormat:@"%@/%@/DB/WCDB_Contact.sqlite", documents, name];
		if ([fileManager fileExistsAtPath:path] && ![candidates containsObject:path]) [others addObject:path];
	}
	[others sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
		NSDate *dateA = [fileManager attributesOfItemAtPath:a error:nil].fileModificationDate ?: [NSDate distantPast];
		NSDate *dateB = [fileManager attributesOfItemAtPath:b error:nil].fileModificationDate ?: [NSDate distantPast];
		return [dateB compare:dateA];
	}];
	[candidates addObjectsFromArray:others];
	PLog(@"LocalInfo.lst 账号=%@ 候选数据库=%@", objects.count > 2 ? objects[2] : @"(读不到)", candidates);
	return candidates;
}

// nil = no row for this user in the database; empty data = row found without an avatar.
static NSData *WCHeadImageBlob(NSString *user, NSString *path) {
	sqlite3 *db = NULL;
	int openResult = sqlite3_open_v2(path.fileSystemRepresentation, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, NULL);
	if (openResult != SQLITE_OK) {
		PLog(@"打开数据库失败 %d %s：%@", openResult, db ? sqlite3_errmsg(db) : "?", path);
		if (db) sqlite3_close(db);
		return nil;
	}
	sqlite3_busy_timeout(db, 300);
	NSData *result = nil;
	sqlite3_stmt *statement = NULL;
	if (sqlite3_prepare_v2(db, "SELECT dbContactHeadImage FROM Friend WHERE userName = ?1 LIMIT 1", -1, &statement, NULL) == SQLITE_OK) {
		sqlite3_bind_text(statement, 1, user.UTF8String, -1, SQLITE_TRANSIENT);
		if (sqlite3_step(statement) == SQLITE_ROW) {
			const void *bytes = sqlite3_column_blob(statement, 0);
			int length = sqlite3_column_bytes(statement, 0);
			result = (bytes && length > 0) ? [NSData dataWithBytes:bytes length:(NSUInteger)length] : [NSData data];
		}
	} else {
		PLog(@"查询失败：%s（%@）", sqlite3_errmsg(db), path);
	}
	sqlite3_finalize(statement);
	sqlite3_close(db);
	return result;
}

static BOOL WCIsURLCharacter(unsigned char c) {
	if (c < 0x21 || c > 0x7e) return NO;
	return strchr("\"*<>\\^`{|}", c) == NULL;
}

// The blob is protobuf: strings are prefixed with a varint length. Use it, else scan printable characters.
static NSArray<NSString *> *WCExtractURLs(NSData *data) {
	const unsigned char *b = data.bytes;
	NSUInteger n = data.length;
	NSMutableArray *urls = [NSMutableArray array];
	for (NSUInteger i = 0; i + 8 < n; i++) {
		if (memcmp(b + i, "http", 4) != 0) continue;
		NSUInteger length = 0;
		if (i >= 2 && (b[i - 2] & 0x80) && b[i - 1] < 0x80) length = (b[i - 2] & 0x7f) | ((NSUInteger)b[i - 1] << 7);
		if ((length == 0 || i + length > n) && i >= 1 && b[i - 1] < 0x80) length = b[i - 1];
		BOOL valid = length > 8 && i + length <= n;
		for (NSUInteger k = 0; valid && k < length; k++) if (!WCIsURLCharacter(b[i + k])) valid = NO;
		if (!valid) {
			length = 0;
			while (i + length < n && WCIsURLCharacter(b[i + length])) length++;
		}
		NSString *url = [[NSString alloc] initWithBytes:b + i length:length encoding:NSASCIIStringEncoding];
		if (url.length > 10) [urls addObject:url];
		i += length ? length - 1 : 0;
	}
	return urls;
}

static NSString *WCPickURL(NSData *blob) {
	NSArray *urls = WCExtractURLs(blob);
	if (urls.count == 0) return nil;
	NSString *pick = nil;
	for (NSString *url in urls) if ([url hasSuffix:@"/0"]) { pick = url; break; }
	if (!pick) pick = urls.firstObject;
	if ([pick hasSuffix:@"/132"]) pick = [[pick substringToIndex:pick.length - 4] stringByAppendingString:@"/0"];
	if ([pick hasPrefix:@"http://"]) pick = [@"https://" stringByAppendingString:[pick substringFromIndex:7]];
	return pick;
}

static NSString *WCAvatarURL(NSString *user) {
	static NSString *lastDatabase = nil;
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ queue = dispatch_queue_create("co.dynastic.ios.tweak.shortlook.plugin.wechat", DISPATCH_QUEUE_SERIAL); });
	__block NSString *result = nil;
	dispatch_sync(queue, ^{
		NSMutableArray *databases = [NSMutableArray array];
		if (lastDatabase) [databases addObject:lastDatabase];
		for (NSString *path in WCDatabaseCandidates()) if (![databases containsObject:path]) [databases addObject:path];
		for (NSString *path in databases) {
			NSData *blob = WCHeadImageBlob(user, path);
			if (!blob) continue;
			lastDatabase = path;
			result = WCPickURL(blob);
			PLog(@"在 %@ 找到 %@，头像数据 %lu 字节，URL=%@", path.lastPathComponent, user, (unsigned long)blob.length, result ?: @"(没解析出 URL)");
			if (!result && blob.length) PLog(@"头像数据前 200 字节：%@", [blob subdataWithRange:NSMakeRange(0, MIN(blob.length, (NSUInteger)200))]);
			return;
		}
		PLog(@"所有数据库里都找不到 %@", user);
	});
	return result;
}

@implementation WeChatContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSDictionary *userInfo = [notification applicationUserInfo];
	NSString *user = WCString(userInfo[@"u"]);
	PLog(@"收到微信通知 u=%@ userInfo=%@", user ?: @"(无)", userInfo);
	if (!user.length) return nil;
	Class offerClass = NSClassFromString(@"DDNotificationContactPhotoPromiseOffer");
	DDNotificationContactPhotoPromiseOffer *offer = [[offerClass alloc] initWithPhotoIdentifier:[@"wechat:" stringByAppendingString:user]];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		NSString *urlString = WCAvatarURL(user);
		NSURL *url = urlString ? [NSURL URLWithString:urlString] : nil;
		if (!url) {
			PLog(@"没有头像 URL，交回 ShortLook");
			[promise reject];
			return;
		}
		NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
		[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			UIImage *image = (data.length && !error) ? [UIImage imageWithData:data] : nil;
			PLog(@"下载 %@：%ld，%lu 字节，%@，错误=%@", url, (long)([response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0), (unsigned long)data.length, image ? @"是图片" : @"不是图片", error.localizedDescription ?: @"无");
			if (image) [promise resolveWithImage:image];
			else [promise reject];
		}] resume];
	}];
	return offer;
}

@end
