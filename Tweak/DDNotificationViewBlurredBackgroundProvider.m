#import "DDNotificationViewBlurredBackgroundProvider.h"
#import "DDRoundedDisplayMatchingInnerShadowView.h"
#import "Private.h"

@implementation DDNotificationViewBlurredBackgroundProvider {
	UIView *containingView;
	_UIBackdropView *view;
	UIView *coveringView;
	DDInnerShadowView *shadowView;
}

- (instancetype)init {
	if ((self = [super init])) {
		containingView = [[UIView alloc] init];

		view = [[NSClassFromString(@"_UIBackdropView") alloc] initWithPrivateStyle:0x802];
		view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[containingView addSubview:view];

		shadowView = [[DDRoundedDisplayMatchingInnerShadowView alloc] init];
		shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		shadowView.shadowSize = 30;
		shadowView.shadowCornerRadius = 100;
		[containingView addSubview:shadowView];

		coveringView = [[UIView alloc] init];
		coveringView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		coveringView.backgroundColor = [UIColor blackColor];
		[containingView addSubview:coveringView];
	}
	return self;
}

- (UIView *)getBackgroundViewWithFrame:(CGRect)frame {
	containingView.frame = frame;
	return containingView;
}

- (void)setBackgroundViewVisible:(BOOL)visible {
	[view transitionToPrivateStyle:visible ? 0x802 : -2];
	shadowView.alpha = visible ? 1 : 0;
	coveringView.alpha = visible ? 0.25 : 0;
}

@end
