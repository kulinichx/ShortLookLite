#import "DDNotificationWindow.h"
#import "DDNotificationView.h"

@implementation DDNotificationWindow

- (instancetype)init {
	if ((self = [super init])) {
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
