#import "DDNotificationAnimationSBProvider.h"
#import "DDUserNotification.h"
#import "DDCoalescedNotification.h"
#import "Private.h"

@implementation DDNotificationAnimationSBProvider {
	NSObject<DDNotificationDisplayable> *notification;
	UIButton *_animationEndView;
	id _listViewController;
}

- (instancetype)initWithNotification:(NSObject<DDNotificationDisplayable> *)aNotification {
	if ((self = [super init])) {
		notification = aNotification;
	}
	return self;
}

- (CGRect)transitionEndRect {
	UIButton *endView = [self animationEndView];
	if (!endView) return CGRectZero;
	CGRect endViewRect = [endView convertRect:endView.bounds toView:nil];
	CGSize imageSize = [[endView imageForState:UIControlStateNormal] size];
	CGRect rect = CGRectMake(endViewRect.origin.x + (endViewRect.size.width * 0.5 - imageSize.width * 0.5), endViewRect.origin.y + (endViewRect.size.height * 0.5 - imageSize.height * 0.5), imageSize.width, imageSize.height);
	UIView *listView = [[self listViewController] view];
	CGRect listFrame = listView.frame;
	UIEdgeInsets insets = listView.safeAreaInsets;
	CGRect visibleRect = CGRectMake(listFrame.origin.x + insets.left, listFrame.origin.y + insets.top, listFrame.size.width - (insets.left + insets.right), listFrame.size.height - (insets.top + insets.bottom));
	if (!CGRectContainsRect(CGRectInset(visibleRect, imageSize.width * -2.0, imageSize.height * -2.0), rect)) return CGRectZero;
	return rect;
}

- (void)didStartTransition {
	UIButton *endView = [self animationEndView];
	if (endView) endView.alpha = 0;
}

- (void)didFinishTransition {
	UIButton *endView = [self animationEndView];
	if (endView) endView.alpha = 1;
}

- (id)listViewController {
	if (!_listViewController) {
		SBDashBoardViewController *dashBoardViewController = [self dashBoardViewController];
		@try {
			_listViewController = [[[dashBoardViewController mainPageContentViewController] combinedListViewController] valueForKey:@"_listViewController"];
		} @catch (NSException *exception) {}
		@try {
			_listViewController = [[[dashBoardViewController mainPageContentViewController] combinedListViewController] valueForKey:@"_structuredListViewController"];
		} @catch (NSException *exception) {}
	}
	return _listViewController;
}

- (SBDashBoardViewController *)dashBoardViewController {
	SBLockScreenManager *manager = [NSClassFromString(@"SBLockScreenManager") sharedInstance];
	if ([manager respondsToSelector:@selector(dashBoardViewController)]) return [manager dashBoardViewController];
	if ([manager respondsToSelector:@selector(coverSheetViewController)]) return [manager coverSheetViewController];
	return nil;
}

- (UIButton *)animationEndView {
	if (_animationEndView) return _animationEndView;
	@try {
		SBLockScreenManager *manager = [NSClassFromString(@"SBLockScreenManager") sharedInstance];
		SBDashBoardViewController *dashBoardViewController = [self dashBoardViewController];
		BOOL hasContentAbove = NO;
		if ([dashBoardViewController respondsToSelector:@selector(hasContentAboveDashBoard)]) {
			hasContentAbove = [dashBoardViewController hasContentAboveDashBoard];
		} else if ([dashBoardViewController respondsToSelector:@selector(hasContentAboveCoverSheet)]) {
			hasContentAbove = [dashBoardViewController hasContentAboveCoverSheet];
		}
		if (!manager.isLockScreenVisible || [manager _isPasscodeVisible] || hasContentAbove || ![dashBoardViewController isMainPageVisible]) return nil;

		DDUserNotification *userNotification = (DDUserNotification *)[self notificationToUseForNotification:nil];
		if (!userNotification || !userNotification.request) return nil;

		id listViewController = [self listViewController];
		if (!listViewController) return nil;

		id cell = nil;
		if ([listViewController isKindOfClass:NSClassFromString(@"NCNotificationListViewController")]) {
			NSIndexPath *indexPath = [(NCNotificationListViewController *)listViewController indexPathForNotificationRequest:userNotification.request];
			if (!indexPath) return nil;
			cell = [[(NCNotificationListViewController *)listViewController collectionView] cellForItemAtIndexPath:indexPath];
		} else if ([listViewController isKindOfClass:NSClassFromString(@"NCNotificationStructuredListViewController")]) {
			NCNotificationListCache *cache = [[(NCNotificationStructuredListViewController *)listViewController masterList] notificationListCache];
			cell = [cache listCellForNotificationRequest:userNotification.request viewControllerDelegate:nil createNewIfNecessary:NO shouldConfigure:NO];
		} else {
			return nil;
		}
		if (!cell) return nil;

		id cellContentView = [(id)[(UIViewController *)[(NCNotificationListCell *)cell contentViewController] view] contentView];
		if (![cellContentView isKindOfClass:NSClassFromString(@"NCNotificationShortLookView")]) return nil;
		NCNotificationShortLookView *shortLookView = cellContentView;
		if ([shortLookView respondsToSelector:@selector(iconButton)]) {
			_animationEndView = [shortLookView iconButton];
		} else if ([shortLookView respondsToSelector:@selector(iconButtons)]) {
			_animationEndView = [[shortLookView iconButtons] firstObject];
		}
		return _animationEndView;
	} @catch (NSException *exception) {
		NSLog(@"[WARNING] Failed to get animationEndView for notification request (failing safely): %@, %@\n%@", exception.name, exception.reason, exception.callStackSymbols);
		return nil;
	}
}

- (NSObject<DDNotificationDisplayable> *)notificationToUseForNotification:(NSObject<DDNotificationDisplayable> *)aNotification {
	if (!aNotification) aNotification = notification;
	if ([aNotification isKindOfClass:[DDUserNotification class]]) return aNotification;
	if ([aNotification isKindOfClass:[DDCoalescedNotification class]]) {
		return [self notificationToUseForNotification:[[(DDCoalescedNotification *)aNotification notifications] lastObject]];
	}
	return nil;
}

@end
