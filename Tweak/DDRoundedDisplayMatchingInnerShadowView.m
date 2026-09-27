#import "DDRoundedDisplayMatchingInnerShadowView.h"
#import "Private.h"

@implementation DDRoundedDisplayMatchingInnerShadowView

- (void)didMoveToWindow {
	[super didMoveToWindow];
	self.shadowCornerRadius = [self displayCornerRadius];
}

- (CGFloat)displayCornerRadius {
	if (!self.window) return 0;
	UIScreen *screen = self.window.screen;
	if (![screen respondsToSelector:@selector(_displayCornerRadius)]) return 0;
	return screen._displayCornerRadius;
}

@end
