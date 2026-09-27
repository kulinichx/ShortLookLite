#import "DDNotificationSBControlSource.h"
#import "DDNotificationViewManager.h"
#import "Private.h"

@implementation DDNotificationSBControlSource {
	BOOL isResumingSleep;
}

- (BOOL)shouldDismissNotification:(NSObject<DDNotificationDisplayable> *)notification forSource:(DDNotificationDismissSource)source {
	if (![self actuallySleepAfterIdlePresentation]) return YES;
	if (source == DDNotificationDismissSourceTimer && !isResumingSleep) {
		isResumingSleep = YES;
		[[NSClassFromString(@"SBScreenWakeAnimationController") sharedInstance] sleepForSource:0 completion:^{
			NSDictionary *options = @{
				@"SBUILockOptionsPreserveTransientOverlaysKey": @YES,
				@"SBUILockOptionsUseScreenOffModeKey": @NO,
				@"SBUILockOptionsIgnoreCallKey": @NO,
				@"SBUILockOptionsAnimateLockScreenActivationKey": @NO
			};
			[[NSClassFromString(@"SBLockScreenManager") sharedInstance] lockUIFromSource:8 withOptions:options completion:^{
				self->isResumingSleep = NO;
				[[DDNotificationViewManager sharedManager] dismissPresentedNotificationForced:YES animationMultiplier:0 forSource:DDNotificationDismissSourceSleep];
			}];
		}];
	}
	return !isResumingSleep;
}

- (void)dismissedNotification:(NSObject<DDNotificationDisplayable> *)notification {
	if ([[notification senderIdentifier] isEqualToString:@"co.dynastic.shortlook-sender.welcome"]) {
		CFPreferencesSetMultiple((__bridge CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"Welcomed"], NULL, CFSTR("co.dynastic.ios.tweak.shortlook"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		CFPreferencesAppSynchronize(CFSTR("co.dynastic.ios.tweak.shortlook"));
		_welcomed = YES;
	}
}

- (BOOL)actuallySleepAfterIdlePresentation {
	return self.sleepAfterIdlePresentation && !self.isDemoing;
}

- (BOOL)shouldAnimateBackgroundDismissForNotification:(NSObject<DDNotificationDisplayable> *)notification withSource:(DDNotificationDismissSource)source {
	if (source != DDNotificationDismissSourceTimer) return YES;
	return ![self actuallySleepAfterIdlePresentation];
}

@end
