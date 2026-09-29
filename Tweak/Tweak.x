#import <UIKit/UIKit.h>
#import "Private.h"
#import "DDNotificationViewSettings.h"
#import "DDNotificationViewManager.h"
#import "DDNotificationWindow.h"
#import "DDNotificationSBControlSource.h"
#import "DDNotificationViewDefaultBackgroundProvider.h"
#import "DDNotificationViewBlurredBackgroundProvider.h"
#import "DDNotificationAnimationSBProvider.h"
#import "DDNotificationContactPhotoProviderManager.h"
#import "DDNotificationContactPhotoProviderPluginLoader.h"
#import "DDNotificationSystemContactPhotoProvider.h"
#import "DDDemoNotificationManager.h"
#import "DDLunarScreenStateManager.h"
#import "DDUserNotification.h"

#define kPreferencesDomain CFSTR("co.dynastic.ios.tweak.shortlook")

@interface SBLiftToWakeController : NSObject
- (void)__ddsl_didStartWake;
@end

static BOOL translucentBackground = YES;
static BOOL enabled = YES;
static BOOL dismissOnRaiseToWake = YES;
static BOOL springBoardLaunched;

static NSURL *applicationSupportURL;
static DDNotificationSBControlSource *controlSource;
static NSTimer *tearDownTimer;
static DDNotificationWindow *notificationWindow;
static NSMutableArray *queuedNotifications;

static void updateBackgroundProvider(void) {
	if (!springBoardLaunched) return;
	Class providerClass = translucentBackground ? [DDNotificationViewBlurredBackgroundProvider class] : [DDNotificationViewDefaultBackgroundProvider class];
	[DDNotificationViewSettings sharedSettings].backgroundViewProviderClass = providerClass;
	[DDNotificationViewSettings sharedSettings].iconMaskImage = [UIImage imageNamed:@"AppIconMask" inBundle:[NSBundle bundleWithIdentifier:@"com.apple.mobileicons.framework"] compatibleWithTraitCollection:nil];
}

static void loadPreferences(void) {
	CFPreferencesAppSynchronize(kPreferencesDomain);
	CFArrayRef keyList = CFPreferencesCopyKeyList(kPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (!keyList) return;
	NSDictionary *preferences = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, kPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	CFRelease(keyList);
	if (!preferences) return;

	if (preferences[@"Enabled"]) enabled = [preferences[@"Enabled"] boolValue];
	if (preferences[@"Welcomed"]) controlSource.welcomed = [preferences[@"Welcomed"] boolValue];
	if (preferences[@"TranslucentBG"]) translucentBackground = [preferences[@"TranslucentBG"] boolValue];
	if (preferences[@"DismissOnRaiseToWake"]) dismissOnRaiseToWake = [preferences[@"DismissOnRaiseToWake"] boolValue];
	if (preferences[@"SleepAfter"]) controlSource.sleepAfterIdlePresentation = [preferences[@"SleepAfter"] boolValue];
	if (preferences[@"WaitDuration"]) [DDNotificationViewSettings sharedSettings].timeUntilDismiss = [preferences[@"WaitDuration"] doubleValue];
	if (preferences[@"LoadContactPhotos"]) [DDNotificationViewSettings sharedSettings].loadContactPhotos = [preferences[@"LoadContactPhotos"] doubleValue] != 0;
	if (preferences[@"ShowNotificationBody"]) [DDNotificationViewSettings sharedSettings].showNotificationBody = [preferences[@"ShowNotificationBody"] boolValue];
	if (preferences[@"ShowSpecialEffects"]) [DDNotificationViewSettings sharedSettings].showSpecialEffects = [preferences[@"ShowSpecialEffects"] boolValue];
	if (preferences[@"HideIcon"]) [DDNotificationViewSettings sharedSettings].hideNotificationIcon = [preferences[@"HideIcon"] boolValue];
}

static void preferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	loadPreferences();
	updateBackgroundProvider();
}

static void createWindowIfNecessary(void) {
	if (notificationWindow) return;
	notificationWindow = [[DDNotificationWindow alloc] init];
	[DDNotificationViewManager sharedManager].targetView = notificationWindow;
}

static void presentWelcomeNotification(void) {
	createWindowIfNecessary();
	[[DDNotificationViewManager sharedManager] presentWelcomeNotification];
}

static void testRequested(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	if (!enabled) return;
	createWindowIfNecessary();
	[[DDNotificationViewManager sharedManager] prepareForDemoNotificationWithCompletion:^{
		SBLockScreenManager *lockScreenManager = [%c(SBLockScreenManager) sharedInstance];
		@try {
			if ([lockScreenManager respondsToSelector:@selector(_activateLockScreenAnimated:animationProvider:automatically:inScreenOffMode:dismissNotificationCenter:completion:)]) {
				[lockScreenManager _activateLockScreenAnimated:NO animationProvider:nil automatically:YES inScreenOffMode:NO dismissNotificationCenter:YES completion:nil];
			} else if ([lockScreenManager respondsToSelector:@selector(_activateLockScreenAnimated:animationProvider:automatically:inScreenOffMode:dimInAnimation:dismissNotificationCenter:completion:)]) {
				[lockScreenManager _activateLockScreenAnimated:NO animationProvider:nil automatically:YES inScreenOffMode:NO dimInAnimation:NO dismissNotificationCenter:YES completion:nil];
			}
		} @catch (NSException *exception) {
		}
		[controlSource setDemoing:YES];
		[[DDDemoNotificationManager sharedManager] sendDemoNotification];
		[NSTimer scheduledTimerWithTimeInterval:[DDNotificationViewSettings sharedSettings].timeUntilDismiss + 1.0 repeats:NO block:^(NSTimer *timer) {
			@try {
				[controlSource setDemoing:NO];
				[[%c(SBLockScreenManager) sharedInstance] unlockUIFromSource:2 withOptions:nil];
				[[DDNotificationViewManager sharedManager] destroyDemoNotificationPreparations];
				[[DDDemoNotificationManager sharedManager] clearDemoNotifications];
			} @catch (NSException *exception) {
				[[DDNotificationViewManager sharedManager] destroyDemoNotificationPreparations];
			}
		}];
	}];
}

static void handleWake(void) {
	if (!enabled) return;
	if (tearDownTimer) [tearDownTimer invalidate];
	if (!controlSource.welcomed && ![[DDNotificationViewManager sharedManager] isPresentingNotification]) {
		presentWelcomeNotification();
		return;
	}
	if (@available(iOS 14, *)) {
		if (queuedNotifications.count == 0) {
			[[DDNotificationViewManager sharedManager] tearDownPresentationIfNotBeingUsed];
			return;
		}
	}
	for (NSDictionary *item in queuedNotifications) {
		DDUserNotification *notification = item[@"notif"];
		NSDate *date = item[@"date"];
		if (!([date timeIntervalSinceNow] < -3.0)) {
			[[DDNotificationViewManager sharedManager] presentNotification:notification];
		}
	}
	[queuedNotifications removeAllObjects];
}

%hook SBNCAlertingController

- (void)_alertNowForNotificationRequest:(NCNotificationRequest *)request {
	%orig;
	if (!enabled || !controlSource.welcomed) return;
	createWindowIfNecessary();
	BOOL lockScreenVisible = [[%c(SBLockScreenManager) sharedInstance] isLockScreenVisible];
	BOOL canTurnOnScreen = [[self screenController] canTurnOnScreenForNotificationRequest:request];
	if (!lockScreenVisible) return;
	if (!canTurnOnScreen) return;
	DDUserNotification *notification = [[DDUserNotification alloc] initWithNotificationRequest:request];
	if (!notification) return;

	if ([controlSource isDemoing]) {
		[[DDNotificationViewManager sharedManager] presentNotification:notification];
		return;
	}

	DDLunarScreenState screenState = [[DDLunarScreenStateManager sharedManager] screenState];
	if (screenState == DDLunarScreenStateOffByProvider) {
		[[DDNotificationViewManager sharedManager] presentNotification:notification];
	} else if (screenState == DDLunarScreenStateOn) {
		if ([[DDNotificationViewManager sharedManager] isPresenting]) {
			[[DDNotificationViewManager sharedManager] presentNotification:notification];
		}
	} else {
		if (@available(iOS 14, *)) {
			[[DDNotificationViewManager sharedManager] prepareForPresentation];
		}
		[queuedNotifications addObject:@{ @"notif": notification, @"date": [NSDate date] }];
		if (tearDownTimer) [tearDownTimer invalidate];
		tearDownTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer *timer) {
			[timer invalidate];
			[[DDNotificationViewManager sharedManager] tearDownPresentationIfNotBeingUsed];
		}];
	}
}

%end

%hook SBScreenWakeAnimationController

- (void)_runCompletionHandlerForWake:(BOOL)wake {
	%orig;
	if (wake) handleWake();
}

- (void)_runCompletionHandlerForWake:(BOOL)wake reason:(id)reason {
	if (wake) {
		handleWake();
		%orig(YES, reason);
	} else {
		%orig(NO, reason);
	}
}

%end

%hook SBLiftToWakeController

%new
- (void)__ddsl_didStartWake {
	if (!dismissOnRaiseToWake || !controlSource.welcomed) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[[DDNotificationViewManager sharedManager] dismissPresentedNotificationForced:YES animationMultiplier:0.5 forSource:DDNotificationDismissSourceRaiseToWake];
	});
}

- (void)wakeGestureManager:(id)manager didUpdateWakeGesture:(long long)gesture {
	%orig;
	if (@available(iOS 12, *)) {
	} else {
		[self __ddsl_didStartWake];
	}
}

- (void)wakeGestureManager:(id)manager didUpdateWakeGesture:(long long)gesture orientation:(int)orientation {
	%orig;
	if (@available(iOS 13, *)) {
	} else if (@available(iOS 12, *)) {
		[self __ddsl_didStartWake];
	}
}

- (void)wakeGestureManager:(id)manager didUpdateWakeGesture:(long long)gesture orientation:(int)orientation detectedAt:(unsigned long long)detectedAt {
	%orig;
	if (@available(iOS 13, *)) {
		[self __ddsl_didStartWake];
	}
}

%end

%hook NCNotificationRequest

+ (id)notificationRequestWithAlertItem:(id)alertItem {
	NCNotificationRequest *request = %orig;
	NSMutableDictionary *sourceInfo = request.sourceInfo ? [request.sourceInfo mutableCopy] : [NSMutableDictionary dictionary];
	BOOL usesSystemIcon = [alertItem respondsToSelector:@selector(_iconImage)] ? ([(SBAlertItem *)alertItem _iconImage] == nil) : YES;
	sourceInfo[@"usesSystemIcon"] = [NSNumber numberWithBool:usesSystemIcon];
	[request setValue:sourceInfo forKey:@"sourceInfo"];
	return request;
}

%end

%hook SBLockScreenManager

- (void)noteMenuButtonSinglePress {
	%orig;
	if (!controlSource.welcomed) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[[DDNotificationViewManager sharedManager] dismissPresentedNotificationForced:YES animationMultiplier:0.5 forSource:DDNotificationDismissSourceMenuButton];
	});
}

%end

%hook SBFUserAuthenticationController

- (void)_handleSuccessfulAuthentication:(id)authentication responder:(id)responder {
	%orig;
	[[DDNotificationViewManager sharedManager] refreshDisplayedNotification];
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
	%orig;
	springBoardLaunched = YES;
	NSBundle *mobileIcons = [NSBundle bundleWithIdentifier:@"com.apple.mobileicons.framework"];
	[DDNotificationViewSettings sharedSettings].defaultIconImage = [UIImage imageNamed:@"DefaultIcon-60" inBundle:mobileIcons compatibleWithTraitCollection:nil];
	[DDNotificationViewSettings sharedSettings].iconMaskImage = [UIImage imageNamed:@"AppIconMask" inBundle:mobileIcons compatibleWithTraitCollection:nil];
	[DDNotificationViewSettings sharedSettings].welcomeNotificationImage = [UIImage imageWithContentsOfFile:[[applicationSupportURL URLByAppendingPathComponent:@"icon.png"] path]];
	[DDNotificationViewSettings sharedSettings].dismissAnimationProviderClass = [DDNotificationAnimationSBProvider class];
	[[DDNotificationContactPhotoProviderManager sharedManager] registerProvider:[DDNotificationSystemContactPhotoProvider class]];
	[DDNotificationViewManager sharedManager].controlSource = controlSource;
	[[[DDNotificationContactPhotoProviderPluginLoader alloc] init] loadPlugins];
	updateBackgroundProvider();
	if (!controlSource.welcomed) presentWelcomeNotification();
}

%end

%ctor {
	@autoreleasepool {
		controlSource = [[DDNotificationSBControlSource alloc] init];
		updateBackgroundProvider();
		loadPreferences();
		updateBackgroundProvider();
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, preferencesChanged, CFSTR("co.dynastic.ios.tweak.shortlook.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, testRequested, CFSTR("co.dynastic.ios.tweak.shortlook.test-requested"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	}
	%init;
	@autoreleasepool {
		applicationSupportURL = [NSURL fileURLWithPath:jbroot(@"/Library/Application Support/Dynastic/ShortLook")];
		queuedNotifications = [NSMutableArray array];
	}
}
