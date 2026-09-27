#import "DDNotificationViewSettings.h"
#import "DDNotificationViewDefaultBackgroundProvider.h"
#import "Private.h"

@implementation DDNotificationViewSettings

+ (instancetype)sharedSettings {
	static DDNotificationViewSettings *sharedSettings;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedSettings = [[self alloc] init];
	});
	return sharedSettings;
}

- (instancetype)init {
	if ((self = [super init])) {
		_timeUntilDismiss = 1.0;
		_animationDurationMultiplier = 1.0;
		_loadContactPhotos = YES;
		_showNotificationBody = NO;
		_hideNotificationIcon = NO;
		_showSpecialEffects = YES;
	}
	return self;
}

- (UIImage *)iconMaskImage {
	return _iconMaskImage ?: [UIImage imageNamed:@"AppIconMask"];
}

- (UIImage *)defaultIconImage {
	return _defaultIconImage ?: [UIImage imageNamed:@"DefaultIcon"];
}

- (UIFont *)notificationTitleFont {
	return _notificationTitleFont ?: [UIFont compactSystemFontOfSize:22 weight:UIFontWeightMedium];
}

- (UIFont *)notificationSubtitleFont {
	return _notificationSubtitleFont ?: [UIFont compactSystemFontOfSize:19 weight:UIFontWeightSemibold];
}

- (UIFont *)notificationSenderTitleFont {
	return _notificationSenderTitleFont ?: [UIFont compactSystemFontOfSize:17 weight:UIFontWeightMedium];
}

- (UIFont *)notificationBodyFont {
	return _notificationBodyFont ?: [self notificationSenderTitleFont];
}

- (UIFont *)notificationFootnoteFont {
	return _notificationFootnoteFont ?: [UIFont compactSystemFontOfSize:15 weight:UIFontWeightSemibold];
}

- (UIFont *)notificationBadgeFont {
	return _notificationBadgeFont ?: [UIFont compactSystemFontOfSize:25];
}

- (UIImage *)welcomeNotificationImage {
	return _welcomeNotificationImage ?: [UIImage imageNamed:@"ShortLook"];
}

- (Class)backgroundViewProviderClass {
	return _backgroundViewProviderClass ?: [DDNotificationViewDefaultBackgroundProvider class];
}

@end
