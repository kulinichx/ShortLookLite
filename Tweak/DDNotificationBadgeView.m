#import "DDNotificationBadgeView.h"
#import "DDNotificationViewSettings.h"

@implementation DDNotificationBadgeView {
	UILabel *label;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.backgroundColor = [UIColor colorWithRed:0.9137 green:0.2 blue:0.1373 alpha:1];
		[self.widthAnchor constraintGreaterThanOrEqualToAnchor:self.heightAnchor].active = YES;
		self.layer.masksToBounds = YES;
		self.alpha = 0;
		self.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.25, 0.25);

		label = [[UILabel alloc] init];
		label.translatesAutoresizingMaskIntoConstraints = NO;
		label.textColor = [UIColor whiteColor];
		label.numberOfLines = 1;
		label.font = [DDNotificationViewSettings sharedSettings].notificationBadgeFont;
		label.textAlignment = NSTextAlignmentCenter;
		[self addSubview:label];
		[label.topAnchor constraintEqualToAnchor:self.topAnchor constant:8].active = YES;
		[label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8].active = YES;
		[label.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:8].active = YES;
		[label.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-8].active = YES;
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) * 0.5;
}

- (void)setShowing:(BOOL)showing {
	if (self.isShowing == showing) return;
	_isShowing = showing;
	self.alpha = showing ? 1 : 0;
	CGFloat scale = showing ? 1 : 0.25;
	self.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale);
}

- (NSString *)text {
	return label.text;
}

- (void)setText:(NSString *)text {
	[self setText:text animated:NO];
}

- (void)setText:(NSString *)text animated:(BOOL)animated {
	if (!animated) {
		[self setShowing:text != nil];
	} else {
		[UIView animateWithDuration:[DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.2 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:1 options:UIViewAnimationOptionAllowUserInteraction animations:^{
			[self setShowing:text != nil];
		} completion:nil];
		CATransition *transition = [[CATransition alloc] init];
		transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		transition.type = kCATransitionFade;
		transition.duration = 0.2;
		transition.removedOnCompletion = YES;
		[label.layer addAnimation:transition forKey:@"textTransition"];
	}
	label.text = text;
}

@end
