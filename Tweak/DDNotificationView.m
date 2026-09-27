#import "DDNotificationView.h"
#import "DDNotificationItemView.h"
#import "DDNotificationViewSettings.h"
#import "DDNotificationViewManager.h"
#import "DDAbstractNotification.h"

@implementation DDNotificationView {
	NSTimer *dismissTimer;
	DDNotificationItemView *notificationView;
	UIView *backgroundView;
	BOOL isForcingDismiss;
	NSObject<DDNotificationViewBackgroundProviding> *backgroundProvider;
	NSMutableArray *animatingViews;
	// The original also creates a DDShortLookSpecialEffectsView here; special effects are not part of this build.
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		animatingViews = [NSMutableArray array];
		backgroundProvider = [[[DDNotificationViewSettings sharedSettings].backgroundViewProviderClass alloc] init];
		backgroundView = [backgroundProvider getBackgroundViewWithFrame:self.bounds];
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self addSubview:backgroundView];
		UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped)];
		[self addGestureRecognizer:tapRecognizer];
	}
	return self;
}

- (NSObject<DDNotificationDisplayable> *)displayedNotification {
	return notificationView ? notificationView.notification : nil;
}

- (void)prepareForPresentation {
	[self setBackgroundViewVisible:YES];
}

- (void)presentNotification:(NSObject<DDNotificationDisplayable> *)notification indefinitely:(BOOL)indefinitely {
	if (isForcingDismiss) return;
	NSObject<DDNotificationDisplayable> *displayedNotification = [self displayedNotification];
	if ([displayedNotification conformsToProtocol:@protocol(DDCoalescableNotification)] && [notification isKindOfClass:[DDAbstractNotification class]] && [[notification senderIdentifier] isEqualToString:[displayedNotification senderIdentifier]]) {
		[self _presentNotification:[(NSObject<DDCoalescableNotification> *)displayedNotification coalescedNotificationWithNotification:notification] indefinitely:indefinitely];
		return;
	}
	[self _presentNotification:notification indefinitely:indefinitely];
}

- (void)_presentNotification:(NSObject<DDNotificationDisplayable> *)notification indefinitely:(BOOL)indefinitely {
	NSObject<DDNotificationDisplayable> *displayedNotification = [self displayedNotification];
	if (displayedNotification && [[notification senderIdentifier] isEqualToString:[displayedNotification senderIdentifier]]) {
		[self restartDismissTimer];
		if (!indefinitely) [notificationView setNotification:notification animated:YES];
		return;
	}

	[self stopDismissTimer];
	[self dismissForced:NO canUseTargetAnimation:NO allowsAnimateBackground:NO forSource:DDNotificationDismissSourceReplaced];

	notificationView = [[DDNotificationItemView alloc] init];
	[notificationView setNotification:notification];
	notificationView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.25, 0.25);
	notificationView.alpha = 0;
	[self addSubview:notificationView];
	[notificationView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
	[notificationView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
	NSArray *sideConstraints = @[
		[notificationView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:25],
		[notificationView.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-25]
	];
	for (NSLayoutConstraint *constraint in sideConstraints) {
		constraint.priority = 750;
	}
	[NSLayoutConstraint activateConstraints:sideConstraints];
	[notificationView.widthAnchor constraintLessThanOrEqualToConstant:400].active = YES;

	[UIView animateWithDuration:[DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.5 delay:0 usingSpringWithDamping:0.95 initialSpringVelocity:1 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
		self->notificationView.transform = CGAffineTransformIdentity;
		self->notificationView.alpha = 1;
		[self setBackgroundViewVisible:YES];
	} completion:^(BOOL finished) {
		if (!indefinitely) [self restartDismissTimer];
		// Matches the original binary, which notifies a dismissal here.
		[[DDNotificationViewManager sharedManager] notifyDismissedNotification:notification];
	}];
}

- (void)refreshDisplayedNotification {
	if (!notificationView || !notificationView.notification) return;
	NSObject *notification = notificationView.notification;
	if ([notification conformsToProtocol:@protocol(DDNotificationRefreshable)] && [notification respondsToSelector:@selector(refreshedNotification)]) {
		NSObject<DDNotificationDisplayable> *refreshedNotification = (NSObject<DDNotificationDisplayable> *)[(NSObject<DDNotificationRefreshable> *)notification refreshedNotification];
		[notificationView setNotification:refreshedNotification animated:YES bounces:NO];
	}
}

- (void)dismissForced:(BOOL)forced canUseTargetAnimation:(BOOL)canUseTargetAnimation allowsAnimateBackground:(BOOL)allowsAnimateBackground forSource:(DDNotificationDismissSource)source {
	[self dismissForced:forced canUseTargetAnimation:canUseTargetAnimation allowsAnimateBackground:allowsAnimateBackground animationMultiplier:1.0 forSource:source];
}

- (void)dismissForced:(BOOL)forced canUseTargetAnimation:(BOOL)canUseTargetAnimation allowsAnimateBackground:(BOOL)allowsAnimateBackground animationMultiplier:(double)animationMultiplier forSource:(DDNotificationDismissSource)source {
	if (isForcingDismiss) return;
	if (![[DDNotificationViewManager sharedManager] requestShouldDismissNotification:notificationView.notification forSource:source]) return;
	if (forced) isForcingDismiss = YES;
	[self stopDismissTimer];

	[UIView animateWithDuration:[DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.2 * animationMultiplier delay:0 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
		for (UIView *view in self->animatingViews) {
			view.alpha = 0;
		}
	} completion:nil];
	animatingViews = [NSMutableArray array];

	DDNotificationItemView *dismissingView = notificationView;
	if (!dismissingView) return;
	notificationView = nil;
	[animatingViews addObject:dismissingView];

	NSObject<DDNotificationAnimationProviding> *animationProvider = [[[DDNotificationViewSettings sharedSettings].dismissAnimationProviderClass alloc] initWithNotification:dismissingView.notification];
	CGRect transitionEndRect = animationProvider ? [animationProvider transitionEndRect] : CGRectZero;

	NSObject<DDNotificationControlSource> *controlSource = [DDNotificationViewManager sharedManager].controlSource;
	if ([controlSource respondsToSelector:@selector(shouldAnimateBackgroundDismissForNotification:withSource:)]) {
		allowsAnimateBackground = allowsAnimateBackground & [controlSource shouldAnimateBackgroundDismissForNotification:dismissingView.notification withSource:source];
	}

	BOOL usesTargetAnimation = NO;
	if (allowsAnimateBackground && canUseTargetAnimation && !CGRectIsEmpty(transitionEndRect)) {
		usesTargetAnimation = [dismissingView.notification allowsPreciseIconTransition];
		if (usesTargetAnimation) [self callSelector:@selector(didStartTransition) onDismissalAnimationProvider:animationProvider];
	}

	NSTimeInterval duration = [DDNotificationViewSettings sharedSettings].animationDurationMultiplier * 0.35 * animationMultiplier;
	[UIView animateWithDuration:duration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0.9 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
		if (!usesTargetAnimation) {
			CGFloat offset = 0;
			if (!forced) offset = dismissingView.bounds.size.height * -0.5;
			dismissingView.transform = CGAffineTransformScale(CGAffineTransformTranslate(CGAffineTransformIdentity, 0, offset), 0.5, 0.5);
			dismissingView.alpha = 0;
		} else {
			if ([animationProvider respondsToSelector:@selector(animateTransitionForNotificationIconView:withDuration:)]) {
				[animationProvider animateTransitionForNotificationIconView:(UIImageView *)dismissingView.iconView.iconImageView withDuration:duration];
			}
			[dismissingView animateIconToFrame:transitionEndRect inView:self.superview];
		}
		if (allowsAnimateBackground) [self setBackgroundViewVisible:NO];
	} completion:^(BOOL finished) {
		if (usesTargetAnimation) [self callSelector:@selector(didFinishTransition) onDismissalAnimationProvider:animationProvider];
		[[DDNotificationViewManager sharedManager] notifyDismissedNotification:dismissingView.notification];
		[self->animatingViews removeObject:dismissingView];
		if (finished) [dismissingView removeFromSuperview];
		if (!self->notificationView) [self requestDestruction];
	}];
}

- (void)dismissByTimer {
	[self dismissForced:NO animationMultiplier:1.0 forSource:DDNotificationDismissSourceTimer];
}

- (void)dismissForced:(BOOL)forced animationMultiplier:(double)animationMultiplier forSource:(DDNotificationDismissSource)source {
	[self dismissForced:forced canUseTargetAnimation:YES allowsAnimateBackground:YES animationMultiplier:animationMultiplier forSource:source];
}

- (void)stopDismissTimer {
	if (dismissTimer) [dismissTimer invalidate];
}

- (void)restartDismissTimer {
	[self stopDismissTimer];
	dismissTimer = [NSTimer scheduledTimerWithTimeInterval:[DDNotificationViewSettings sharedSettings].timeUntilDismiss target:self selector:@selector(dismissByTimer) userInfo:nil repeats:NO];
}

- (void)requestDestruction {
	if (self.delegate) [self.delegate handleDestructionRequestFromNotificationView:self];
}

- (void)callSelector:(SEL)selector onDismissalAnimationProvider:(NSObject<DDNotificationAnimationProviding> *)animationProvider {
	if (animationProvider && [animationProvider respondsToSelector:selector]) {
		[animationProvider performSelectorOnMainThread:selector withObject:nil waitUntilDone:NO];
	}
}

- (void)setBackgroundViewVisible:(BOOL)visible {
	[backgroundView.layer removeAllAnimations];
	if ([backgroundProvider respondsToSelector:@selector(setBackgroundViewVisible:)]) {
		[backgroundProvider setBackgroundViewVisible:visible];
	} else {
		backgroundView.alpha = visible;
	}
}

- (void)viewTapped {
	[self dismissForced:YES canUseTargetAnimation:NO allowsAnimateBackground:YES forSource:DDNotificationDismissSourceTap];
}

@end
