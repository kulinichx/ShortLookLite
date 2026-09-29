#import "DDNotificationViewManager.h"
#import "DDNotificationViewController.h"
#import "DDWelcomeNotification.h"

// iPhone 14 Pro port: the lock glyph lives in the Dynamic Island (SystemAperture scene), which sits
// above every SpringBoard window. On the notch devices ShortLook was made for, that glyph was part of
// the lock screen and ShortLook's full-screen window covered it. Hide the island's windows while
// ShortLook is on screen and put them back afterwards so it looks the way the original did.
static NSMutableArray<UIWindow *> *hiddenApertureWindows;
static NSMutableArray<NSNumber *> *hiddenApertureAlphas;

static void SLSetSystemApertureHidden(BOOL hidden) {
	if (hidden) {
		if (hiddenApertureWindows) return;
		hiddenApertureWindows = [NSMutableArray array];
		hiddenApertureAlphas = [NSMutableArray array];
		for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
			if (![scene isKindOfClass:[UIWindowScene class]] || ![scene.session.role containsString:@"SystemAperture"]) continue;
			for (UIWindow *window in ((UIWindowScene *)scene).windows) {
				if (window.hidden) continue;
				[hiddenApertureWindows addObject:window];
				[hiddenApertureAlphas addObject:@(window.alpha)];
				window.alpha = 0;
			}
		}
	} else {
		if (!hiddenApertureWindows) return;
		[hiddenApertureWindows enumerateObjectsUsingBlock:^(UIWindow *window, NSUInteger index, BOOL *stop) {
			window.alpha = hiddenApertureAlphas[index].doubleValue;
		}];
		hiddenApertureWindows = nil;
		hiddenApertureAlphas = nil;
	}
}

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
	SLSetSystemApertureHidden(YES);
}

- (void)destroyView:(UIView *)view {
	if (view) [view removeFromSuperview];
	if ([_targetView isKindOfClass:[UIWindow class]]) {
		if ([(UIWindow *)_targetView rootViewController] == (id)[view nextResponder]) {
			[(UIWindow *)_targetView setRootViewController:nil];
		}
	}
	if ([viewController notificationView] == view) viewController = nil;
	if (!viewController) SLSetSystemApertureHidden(NO);
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
