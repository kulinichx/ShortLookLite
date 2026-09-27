#import "DDNotificationContactPhotoPromiseOffer.h"

@implementation DDNotificationContactPhotoPromiseOffer {
	void (^fulfiller)(DDNotificationContactPhotoPromise *promise);
	BOOL isNeeded;
}

- (instancetype)initWithPhotoIdentifier:(NSString *)photoIdentifier {
	if ((self = [super init])) {
		isNeeded = NO;
		_photoIdentifier = photoIdentifier;
	}
	return self;
}

+ (instancetype)offerInstantlyResolvingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier image:(UIImage *)image {
	return [self offerInstantlyResolvingPromiseWithPhotoIdentifier:photoIdentifier image:image withSettings:nil];
}

+ (instancetype)offerInstantlyResolvingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier image:(UIImage *)image withSettings:(DDNotificationContactPhotoSettings *)settings {
	DDNotificationContactPhotoPromiseOffer *offer = [[[self class] alloc] initWithPhotoIdentifier:photoIdentifier];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		if (settings) promise.settings = settings;
		[promise resolveWithImage:image];
	}];
	return offer;
}

+ (instancetype)offerDownloadingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier fromURL:(NSURL *)url {
	return [self offerDownloadingPromiseWithPhotoIdentifier:photoIdentifier fromURL:url withSettings:nil];
}

+ (instancetype)offerDownloadingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier fromURL:(NSURL *)url withSettings:(DDNotificationContactPhotoSettings *)settings {
	DDNotificationContactPhotoPromiseOffer *offer = [[[self class] alloc] initWithPhotoIdentifier:photoIdentifier];
	[offer fulfillWithBlock:^(DDNotificationContactPhotoPromise *promise) {
		NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:3];
		[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			if (settings) promise.settings = settings;
			if (!data || error) {
				[promise reject];
				return;
			}
			UIImage *image = [UIImage imageWithData:data];
			if (image) [promise resolveWithImage:image];
			else [promise reject];
		}] resume];
	}];
	return offer;
}

- (void)fulfillWithBlock:(void (^)(DDNotificationContactPhotoPromise *promise))block {
	fulfiller = [block copy];
}

- (DDNotificationContactPhotoPromise *)generatePromise {
	DDNotificationContactPhotoPromise *promise = [[DDNotificationContactPhotoPromise alloc] init];
	[[NSOperationQueue new] addOperationWithBlock:^{
		if (self && self->fulfiller) self->fulfiller(promise);
	}];
	return promise;
}

@end
