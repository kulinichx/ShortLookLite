// QQ contact photos for ShortLook (ShortLook Contact Photo Provider API v1).
// userInfo["r"] is "c|<QQ number>" for friends or "g|<group number>" for groups.
#import "ShortLook-API.h"

@interface QQContactPhotoProvider : NSObject <DDNotificationContactPhotoProviding>
@end

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
		if (image && image.size.width >= 20) [promise resolveWithImage:image];
		else QQDownload(rest, promise);
	}] resume];
}

@implementation QQContactPhotoProvider

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSArray *parts = [QQString([notification applicationUserInfo][@"r"]) componentsSeparatedByString:@"|"];
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
