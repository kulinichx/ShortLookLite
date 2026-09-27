#import "DDNotificationContactPhotoSettings.h"

@implementation DDNotificationContactPhotoSettings

- (instancetype)init {
	if ((self = [super init])) {
		_usesCaching = YES;
	}
	return self;
}

- (UIColor *)backgroundColor {
	return _backgroundColor ?: [DDNotificationContactPhotoSettings defaultBackgroundColor];
}

+ (UIColor *)defaultBackgroundColor {
	return [UIColor colorWithWhite:1 alpha:0.1];
}

@end
