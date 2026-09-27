// QQ contact photos for ShortLook (ShortLook Contact Photo Provider API v1).
// userInfo["r"] is "c|<QQ number>" for friends or "g|<group number>" for groups.
#import "ShortLook-API.h"

@interface QQContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

// Diagnostic log: /var/mobile/Library/Caches/ShortLook/QQ.log
static void PLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void PLog(NSString *format, ...) {
	va_list arguments;
	va_start(arguments, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	NSLog(@"[ShortLook-QQ] %@", message);
	static dispatch_queue_t queue;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ queue = dispatch_queue_create("shortlook.plugin.QQ.log", DISPATCH_QUEUE_SERIAL); });
	NSDate *date = [NSDate date];
	dispatch_async(queue, ^{
		NSString *directory = @"/var/mobile/Library/Caches/ShortLook";
		[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *path = [directory stringByAppendingPathComponent:@"QQ.log"];
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

static NSString *QQString(id value) {
	if ([value isKindOfClass:[NSString class]]) return value;
	if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
	return nil;
}

static void QQDownload(NSArray<NSURL *> *urls, DDNotificationContactPhotoPromise *promise) {
	if (urls.count == 0) {
		[promise reject];
		return;
	}
	NSArray *rest = [urls subarrayWithRange:NSMakeRange(1, urls.count - 1)];
	NSURLRequest *request = [NSURLRequest requestWithURL:urls.firstObject cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
		UIImage *image = (data.length && statusCode == 200) ? [UIImage imageWithData:data] : nil;
		PLog(@"下载 %@：%ld，%lu 字节，%@", urls.firstObject, (long)statusCode, (unsigned long)data.length, image ? @"是图片" : @"不是图片");
		if (image && image.size.width >= 20) [promise resolveWithImage:image];
		else QQDownload(rest, promise);
	}] resume];
}

@implementation QQContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSDictionary *userInfo = [notification applicationUserInfo];
	PLog(@"收到 QQ 通知 r=%@ userInfo=%@", userInfo[@"r"] ?: @"(无)", userInfo);
	NSArray *parts = [QQString(userInfo[@"r"]) componentsSeparatedByString:@"|"];
	if (parts.count < 2 || ![parts[1] length]) return nil;
	NSString *type = parts[0];
	NSString *number = parts[1];
	NSArray<NSString *> *urlStrings;
	if ([type isEqualToString:@"g"]) {
		urlStrings = @[[NSString stringWithFormat:@"https://p.qlogo.cn/gh/%@/%@/640", number, number],
		               [NSString stringWithFormat:@"https://p.qlogo.cn/gh/%@/%@/140", number, number]];
	} else {
		urlStrings = @[[NSString stringWithFormat:@"https://q1.qlogo.cn/g?b=qq&s=640&nk=%@", number],
		               [NSString stringWithFormat:@"https://q1.qlogo.cn/g?b=qq&s=140&nk=%@", number]];
	}
	NSMutableArray<NSURL *> *urls = [NSMutableArray array];
	for (NSString *string in urlStrings) {
		NSURL *url = [NSURL URLWithString:string];
		if (url) [urls addObject:url];
	}
	Class offerClass = NSClassFromString(@"DDNotificationContactPhotoPromiseOffer");
	DDNotificationContactPhotoPromiseOffer *offer = [[offerClass alloc] initWithPhotoIdentifier:[NSString stringWithFormat:@"qq:%@:%@", type, number]];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		QQDownload(urls, promise);
	}];
	return offer;
}

@end
