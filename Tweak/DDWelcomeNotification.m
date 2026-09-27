#import "DDWelcomeNotification.h"
#import "DDNotificationViewSettings.h"

@implementation DDWelcomeNotification

- (NSString *)title {
	return @"Welcome to ShortLook";
}

- (NSString *)senderTitle {
	return nil;
}

- (UIImage *)icon {
	return [DDNotificationViewSettings sharedSettings].welcomeNotificationImage;
}

- (NSString *)senderIdentifier {
	return @"co.dynastic.shortlook-sender.welcome";
}

- (NSString *)body {
	return @"Thank you for purchasing ShortLook. When you receive a notification while your device is locked, it will wake your device and display on your Lock Screen. You can adjust the look and behaviour of ShortLook in Settings.";
}

- (NSString *)footnote {
	return @"Tap to dismiss";
}

- (BOOL)allowsPreciseIconTransition {
	return NO;
}

- (BOOL)allowsBodyTruncation {
	return NO;
}

@end
