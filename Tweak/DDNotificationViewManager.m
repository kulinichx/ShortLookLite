#import "DDNotificationViewManager.h"
#import "DDNotificationViewController.h"
#import "DDWelcomeNotification.h"

@implementation DDNotificationViewManager {
	DDNotificationViewController *viewController;
	UIView *demoCurtainView;
}

+ (instancetype)sharedManager {
	static DDNotificationViewManager *sharedManager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

- (void)createViewIfDoesntExist {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(createViewIfDoesntExist) withObject:nil waitUntilDone:YES];
		return;
	}
	[self destroyDemoNotificationPreparations];
	if (viewController || !_targetView) return;
	viewController = [[DDNotificationViewController alloc] init];
	viewController.view.frame = _targetView.bounds;
	viewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[viewController notificationView].delegate = self;
	if ([_targetView isKindOfClass:[UIWindow class]]) {
		[(UIWindow *)_targetView setRootViewController:viewController];
	}
	[_targetView addSubview:viewController.view];
}

- (void)destroyView:(UIView *)view {
	if (view) [view removeFromSuperview];
	if ([_targetView isKindOfClass:[UIWindow class]]) {
		if ([(UIWindow *)_targetView rootViewController] == (id)[view nextResponder]) {
			[(UIWindow *)_targetView setRootViewController:nil];
		}
	}
	if ([viewController notificationView] == view) viewController = nil;
}

- (void)destroyView {
	[self destroyView:[viewController notificationView]];
}

- (void)prepareForPresentation {
	[self createViewIfDoesntExist];
	if (viewController) [[viewController notificationView] prepareForPresentation];
}

- (void)tearDownPresentationIfNotBeingUsed {
	if (viewController && ![self isPresentingNotification]) {
		[self destroyView:[viewController notificationView]];
	}
}

- (void)presentNotification:(NSObject<DDNotificationDisplayable> *)notification {
	[self presentNotification:notification indefinitely:NO];
}

- (void)presentNotification:(NSObject<DDNotificationDisplayable> *)notification indefinitely:(BOOL)indefinitely {
	[self createViewIfDoesntExist];
	if (viewController) [[viewController notificationView] presentNotification:notification indefinitely:indefinitely];
}

- (void)dismissPresentedNotificationForced:(BOOL)forced forSource:(DDNotificationDismissSource)source {
	[self dismissPresentedNotificationForced:forced animationMultiplier:1.0 forSource:source];
}

- (void)dismissPresentedNotificationForced:(BOOL)forced animationMultiplier:(double)animationMultiplier forSource:(DDNotificationDismissSource)source {
	if (viewController) [[viewController notificationView] dismissForced:forced animationMultiplier:animationMultiplier forSource:source];
}

- (void)refreshDisplayedNotification {
	if (viewController) [[viewController notificationView] refreshDisplayedNotification];
}

- (void)presentWelcomeNotification {
	[self presentNotification:[[DDWelcomeNotification alloc] init] indefinitely:YES];
}

- (BOOL)isPresenting {
	return viewController != nil;
}

- (BOOL)isPresentingNotification {
	if (!viewController) return NO;
	return [[viewController notificationView] displayedNotification] != nil;
}

- (void)notifyPresentedNotification:(NSObject<DDNotificationDisplayable> *)notification {
	if (self.controlSource && [self.controlSource respondsToSelector:@selector(presentedNotification:)]) {
		[self.controlSource presentedNotification:notification];
	}
}

- (void)notifyDismissedNotification:(NSObject<DDNotificationDisplayable> *)notification {
	if (self.controlSource && [self.controlSource respondsToSelector:@selector(dismissedNotification:)]) {
		[self.controlSource dismissedNotification:notification];
	}
}

- (BOOL)requestShouldDismissNotification:(NSObject<DDNotificationDisplayable> *)notification forSource:(DDNotificationDismissSource)source {
	if (!self.controlSource) return YES;
	return [self.controlSource shouldDismissNotification:notification forSource:source];
}

- (void)handleDestructionRequestFromNotificationView:(UIView *)notificationView {
	[self destroyView:notificationView];
}

- (void)prepareForDemoNotificationWithCompletion:(void (^)(void))completion {
	if (demoCurtainView) [demoCurtainView removeFromSuperview];
	if (!_targetView) return;
	demoCurtainView = [[UIView alloc] initWithFrame:_targetView.bounds];
	demoCurtainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	demoCurtainView.backgroundColor = [UIColor blackColor];
	demoCurtainView.alpha = 0;
	[_targetView addSubview:demoCurtainView];
	[UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.9 options:UIViewAnimationOptionAllowUserInteraction animations:^{
		self->demoCurtainView.alpha = 1;
	} completion:^(BOOL finished) {
		if (finished) {
			completion();
			return;
		}
		[self destroyDemoNotificationPreparations];
	}];
}

- (void)destroyDemoNotificationPreparations {
	if (demoCurtainView) [demoCurtainView removeFromSuperview];
	demoCurtainView = nil;
}

@end
