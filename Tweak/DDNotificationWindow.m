#import "DDNotificationWindow.h"
#import "DDNotificationView.h"

@implementation DDNotificationWindow

- (instancetype)init {
	if ((self = [super init])) {
		// iOS 16 port: since iOS 13 a window must belong to a UIWindowScene to be shown. The original
		// (iOS 11-14) created the window with -init only; attach it to the main screen's scene here.
		if (@available(iOS 13, *)) {
			if (!self.windowScene) {
				// Prefer SpringBoard's main scene; on the iPhone 14 Pro there is also a SystemAperture
				// (Dynamic Island) scene on the same screen, and connectedScenes is unordered.
				UIWindowScene *scene = nil;
				UIWindowScene *fallbackScene = nil;
				for (UIScene *candidate in [UIApplication sharedApplication].connectedScenes) {
					if (![candidate isKindOfClass:[UIWindowScene class]] || ((UIWindowScene *)candidate).screen != [UIScreen mainScreen]) continue;
					if ([candidate.session.persistentIdentifier isEqualToString:@"com.apple.springboard"]) {
						scene = (UIWindowScene *)candidate;
						break;
					}
					if (!fallbackScene && ![candidate.session.role containsString:@"SystemAperture"]) fallbackScene = (UIWindowScene *)candidate;
				}
				if (!scene) scene = fallbackScene;
				if (!scene) {
					for (UIWindow *window in [UIApplication sharedApplication].windows) {
						if (window.windowScene && window.windowScene.screen == [UIScreen mainScreen]) {
							scene = window.windowScene;
							break;
						}
					}
				}
				if (scene) self.windowScene = scene;
			}
		}
		self.frame = [UIScreen mainScreen].bounds;
		self.backgroundColor = nil;
		self.hidden = NO;
		self.windowLevel = 1106;
	}
	return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	for (UIView *subview in self.subviews) {
		if ([subview isKindOfClass:[DDNotificationView class]]) return subview;
	}
	return nil;
}

- (BOOL)_shouldCreateContextAsSecure {
	return YES;
}

@end
