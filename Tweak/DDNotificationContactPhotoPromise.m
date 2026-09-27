#import "DDNotificationContactPhotoPromise.h"

@implementation DDNotificationContactPhotoPromise {
	UIImage *result;
}

- (instancetype)init {
	if ((self = [super init])) {
		_callbacks = [[NSMutableArray alloc] init];
		_settings = [[DDNotificationContactPhotoSettings alloc] init];
	}
	return self;
}

- (void)resolveWithImage:(UIImage *)image {
	if (_isComplete) return;
	result = image ? [image copy] : nil;
	_isComplete = YES;
	for (void (^callback)(UIImage *) in _callbacks) {
		callback(image);
	}
}

- (void)reject {
	[self resolveWithImage:nil];
}

- (void)registerForUpdatesWithHandler:(void (^)(UIImage *image))handler {
	if (!handler) return;
	if (result) {
		handler(result);
	} else if (_callbacks) {
		[_callbacks addObject:[handler copy]];
	}
}

@end
