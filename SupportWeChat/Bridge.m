#import "SLWeChatSupportController.h"
#import "../SupportShared/SLDonationRequest.h"
#import <objc/runtime.h>

// Existing package dependency; no payment SDK or extra plugin is required.
extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

static NSMutableDictionary<NSString *, NSValue *> *SLOriginalMethods;
static NSMutableArray<NSString *> *SLConsumedRequests;
static NSString *SLPendingRequest;
static NSTimeInterval SLPendingTimestamp;
static NSUInteger SLPendingAttempt;
static void (*SLOriginalSetAppDelegate)(UIApplication *, SEL, id);
static void (*SLOriginalSetSceneDelegate)(UIScene *, SEL, id);

static NSString *SLMethodKey(Class cls, SEL selector) {
	return [NSString stringWithFormat:@"%@/%@", NSStringFromClass(cls), NSStringFromSelector(selector)];
}

static IMP SLOriginal(id object, SEL selector) {
	for (Class cls = object_getClass(object); cls; cls = class_getSuperclass(cls)) {
		NSValue *value = SLOriginalMethods[SLMethodKey(cls, selector)];
		if (value) return [value pointerValue];
	}
	return NULL;
}

static UIViewController *SLTopController(void) {
	for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]] || scene.activationState != UISceneActivationStateForegroundActive) continue;
		for (UIWindow *window in [(UIWindowScene *)scene windows]) {
			if (!window.isKeyWindow || window.hidden) continue;
			UIViewController *controller = window.rootViewController;
			for (NSUInteger i = 0; controller && i < 20; i++) {
				UIViewController *next = controller.presentedViewController;
				if (!next && [controller isKindOfClass:[UINavigationController class]]) next = [(UINavigationController *)controller visibleViewController];
				if (!next && [controller isKindOfClass:[UITabBarController class]]) next = [(UITabBarController *)controller selectedViewController];
				if (!next || next == controller) return controller;
				controller = next;
			}
		}
	}
	return nil;
}

static void SLTryOpenNativeSupport(void) {
	if (!SLPendingRequest) return;
	if (!SLDonationTimestampIsFresh(SLPendingTimestamp, [[NSDate date] timeIntervalSince1970]) || SLPendingAttempt++ >= 120) {
		SLPendingRequest = nil;
		return;
	}
	UIViewController *top = SLTopController();
	BOOL active = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
	// 与 WCRefine 一样需要一个位于导航栈里的可见页面，微信会在该导航栈推出原生赞赏页
	if (active && top.view.window && top.navigationController && !top.isBeingDismissed && !top.isBeingPresented && ![top isKindOfClass:[UIAlertController class]]) {
		SLPendingRequest = nil;
		__weak UIViewController *weakTop = top;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			UIViewController *presenter = weakTop;
			if (presenter.view.window) SLOpenWeChatNativeAppreciation(presenter);
		});
		return;
	}
	NSString *request = SLPendingRequest;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if ([SLPendingRequest isEqualToString:request]) SLTryOpenNativeSupport();
	});
}

static BOOL SLConsumeURL(NSURL *url, NSString *sourceApplication) {
	if (![url isKindOfClass:[NSURL class]]) return NO;
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	if (![components.scheme.lowercaseString isEqualToString:SLDonationScheme] || ![components.host.lowercaseString isEqualToString:SLDonationHost]) return NO;
	// Consume only our own host, and never forward malformed requests into WeChat's normal URL handling.
	if (sourceApplication && (![sourceApplication isKindOfClass:[NSString class]] || [sourceApplication caseInsensitiveCompare:@"com.apple.Preferences"] != NSOrderedSame)) return YES;
	if (![components.path isEqualToString:SLDonationPath] || components.user || components.password || components.port || components.fragment) return YES;
	if (components.queryItems.count != 3) return YES;
	NSMutableDictionary *values = [NSMutableDictionary dictionary];
	for (NSURLQueryItem *item in components.queryItems) {
		if (![@[@"v", @"nonce", @"timestamp"] containsObject:item.name] || values[item.name] || !item.value.length) return YES;
		values[item.name] = item.value;
	}
	if (![values[@"v"] isEqualToString:@"3"]) return YES;
	NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:values[@"nonce"]];
	double timestamp = 0;
	NSScanner *scanner = [NSScanner scannerWithString:values[@"timestamp"] ?: @""];
	if (!uuid || ![scanner scanDouble:&timestamp] || !scanner.isAtEnd ||
		!SLDonationTimestampIsFresh(timestamp, [[NSDate date] timeIntervalSince1970])) return YES;
	NSString *nonce = uuid.UUIDString;
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([SLConsumedRequests containsObject:nonce]) return;
		[SLConsumedRequests addObject:nonce];
		if (SLConsumedRequests.count > 32) [SLConsumedRequests removeObjectAtIndex:0];
		SLPendingRequest = nonce;
		SLPendingTimestamp = timestamp;
		SLPendingAttempt = 0;
		SLTryOpenNativeSupport();
	});
	return YES;
}

static BOOL SLAppOpenURL(id object, SEL selector, UIApplication *application, NSURL *url, NSDictionary *options) {
	if (SLConsumeURL(url, options[UIApplicationOpenURLOptionsSourceApplicationKey])) return YES;
	IMP original = SLOriginal(object, selector);
	return original ? ((BOOL (*)(id, SEL, UIApplication *, NSURL *, NSDictionary *))original)(object, selector, application, url, options) : NO;
}

static BOOL SLAppLegacyURL(id object, SEL selector, UIApplication *application, NSURL *url, NSString *source, id annotation) {
	if (SLConsumeURL(url, source)) return YES;
	IMP original = SLOriginal(object, selector);
	return original ? ((BOOL (*)(id, SEL, UIApplication *, NSURL *, NSString *, id))original)(object, selector, application, url, source, annotation) : NO;
}

static BOOL SLAppHandleURL(id object, SEL selector, UIApplication *application, NSURL *url) {
	if (SLConsumeURL(url, nil)) return YES;
	IMP original = SLOriginal(object, selector);
	return original ? ((BOOL (*)(id, SEL, UIApplication *, NSURL *))original)(object, selector, application, url) : NO;
}

static NSSet<UIOpenURLContext *> *SLFilterContexts(NSSet<UIOpenURLContext *> *contexts) {
	NSMutableSet *remaining = [NSMutableSet set];
	for (UIOpenURLContext *context in contexts) {
		if (!SLConsumeURL(context.URL, context.options.sourceApplication)) [remaining addObject:context];
	}
	return remaining;
}

static void SLSceneOpenURLs(id object, SEL selector, UIScene *scene, NSSet<UIOpenURLContext *> *contexts) {
	NSSet *remaining = SLFilterContexts(contexts);
	IMP original = SLOriginal(object, selector);
	if (original && remaining.count) ((void (*)(id, SEL, UIScene *, NSSet *))original)(object, selector, scene, remaining);
}

static void SLSceneConnect(id object, SEL selector, UIScene *scene, UISceneSession *session, UISceneConnectionOptions *options) {
	IMP original = SLOriginal(object, selector);
	// Preserve all scene startup options; handle our request after WeChat establishes its window.
	if (original) ((void (*)(id, SEL, UIScene *, UISceneSession *, UISceneConnectionOptions *))original)(object, selector, scene, session, options);
	SLFilterContexts(options.URLContexts);
}

static void SLHookMethod(Class cls, SEL selector, IMP replacement) {
	NSString *key = SLMethodKey(cls, selector);
	Method method = class_getInstanceMethod(cls, selector);
	if (!method || method_getImplementation(method) == replacement || SLOriginalMethods[key]) return;
	IMP original = NULL;
	MSHookMessageEx(cls, selector, replacement, &original);
	if (original) SLOriginalMethods[key] = [NSValue valueWithPointer:original];
}

static void SLHookAppDelegate(id delegate) {
	if (!delegate) return;
	Class cls = object_getClass(delegate);
	SLHookMethod(cls, @selector(application:openURL:options:), (IMP)SLAppOpenURL);
	SLHookMethod(cls, @selector(application:openURL:sourceApplication:annotation:), (IMP)SLAppLegacyURL);
	SLHookMethod(cls, @selector(application:handleOpenURL:), (IMP)SLAppHandleURL);
}

static void SLHookSceneDelegate(id delegate) {
	if (!delegate) return;
	Class cls = object_getClass(delegate);
	SLHookMethod(cls, @selector(scene:openURLContexts:), (IMP)SLSceneOpenURLs);
	SLHookMethod(cls, @selector(scene:willConnectToSession:options:), (IMP)SLSceneConnect);
}

static void SLSetAppDelegate(UIApplication *application, SEL selector, id delegate) {
	SLHookAppDelegate(delegate);
	if (SLOriginalSetAppDelegate) SLOriginalSetAppDelegate(application, selector, delegate);
}

static void SLSetSceneDelegate(UIScene *scene, SEL selector, id delegate) {
	SLHookSceneDelegate(delegate);
	if (SLOriginalSetSceneDelegate) SLOriginalSetSceneDelegate(scene, selector, delegate);
}

__attribute__((constructor)) static void SLInitializeSupportBridge(void) {
	@autoreleasepool {
		if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.tencent.xin"]) return;
		SLOriginalMethods = [NSMutableDictionary dictionary];
		SLConsumedRequests = [NSMutableArray array];
		MSHookMessageEx([UIApplication class], @selector(setDelegate:), (IMP)SLSetAppDelegate, (IMP *)&SLOriginalSetAppDelegate);
		if (class_getInstanceMethod([UIScene class], @selector(setDelegate:))) MSHookMessageEx([UIScene class], @selector(setDelegate:), (IMP)SLSetSceneDelegate, (IMP *)&SLOriginalSetSceneDelegate);
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		[center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
			SLHookAppDelegate([UIApplication sharedApplication].delegate);
			SLConsumeURL(note.userInfo[UIApplicationLaunchOptionsURLKey], note.userInfo[UIApplicationLaunchOptionsSourceApplicationKey]);
		}];
		[center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
			SLHookAppDelegate([UIApplication sharedApplication].delegate);
			for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) SLHookSceneDelegate(scene.delegate);
			SLTryOpenNativeSupport();
		}];
		dispatch_async(dispatch_get_main_queue(), ^{
			SLHookAppDelegate([UIApplication sharedApplication].delegate);
			for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) SLHookSceneDelegate(scene.delegate);
		});
	}
}
