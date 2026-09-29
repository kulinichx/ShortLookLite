#import "DDDemoNotificationManager.h"
#import "Private.h"

@implementation DDDemoNotificationManager {
	NSMutableArray *sentNotifications;
}

+ (instancetype)sharedManager {
	static DDDemoNotificationManager *sharedManager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

- (instancetype)init {
	if ((self = [super init])) {
		sentNotifications = [NSMutableArray array];
	}
	return self;
}

- (void)sendDemoNotification {
	// iOS 16 port: an exception here used to take SpringBoard down (safe mode); log it instead.
	@try {
		NCNotificationRequest *request = [self notificationRequestForTitle:@"Hello from ShortLook!" content:@"This is a test notification from ShortLook." fromApplicationIdentifier:[self randomBundleIdentifier]];
		if (!request) {
			return;
		}
		NCNotificationDispatcher *dispatcher = [(SpringBoard *)[UIApplication sharedApplication] notificationDispatcher].dispatcher;
		[dispatcher postNotificationWithRequest:request];
		[sentNotifications addObject:request];
	} @catch (NSException *exception) {
	}
}

- (NCNotificationRequest *)notificationRequestForTitle:(NSString *)title content:(NSString *)content fromApplicationIdentifier:(NSString *)applicationIdentifier {
	NSSet *destinations = [NSSet setWithObjects:@"BulletinDestinationCoverSheet", @"BulletinDestinationNotificationCenter", @"BulletinDestinationLockScreen", nil];
	NCNotificationRequest *request = nil;
	Class requestClass = NSClassFromString(@"NCNotificationRequest");
	if ([requestClass respondsToSelector:@selector(notificationRequestWithSectionId:notificationId:threadId:title:message:timestamp:destinations:)]) {
		request = [requestClass notificationRequestWithSectionId:applicationIdentifier notificationId:@"shortlook-demo" threadId:@"shortlook-demo" title:title message:content timestamp:[NSDate date] destinations:destinations];
	} else {
		// iOS 15+ port: the convenience constructor above no longer exists; build the same request by hand.
		request = [self _mutableNotificationRequestWithSectionIdentifier:applicationIdentifier title:title message:content destinations:destinations];
	}
	if (!request) return nil;
	SBApplication *application = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:applicationIdentifier];
	if (!application) {
		[request.content safelySetValue:applicationIdentifier forKey:@"header"];
	} else {
		[request.content safelySetValue:application.displayName forKey:@"header"];
		UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:application.bundleIdentifier format:5 scale:[UIScreen mainScreen].scale];
		[request.content safelySetValue:icon forKey:@"_icon"];
		[request.content safelySetValue:@[icon] forKey:@"_icons"];
	}
	[request.content safelySetValue:[NSDate date] forKey:@"_date"];
	[request.options safelySetValue:[NSNumber numberWithInt:1] forKey:@"_canTurnOnDisplay"];
	[request.options safelySetValue:[NSNumber numberWithInt:1] forKey:@"_alertsWhenLocked"];
	[request.options safelySetValue:[NSNumber numberWithInt:1] forKey:@"_overridesQuietMode"];
	return request;
}

- (NCNotificationRequest *)_mutableNotificationRequestWithSectionIdentifier:(NSString *)sectionIdentifier title:(NSString *)title message:(NSString *)message destinations:(NSSet *)destinations {
	Class requestClass = NSClassFromString(@"NCMutableNotificationRequest");
	Class contentClass = NSClassFromString(@"NCMutableNotificationContent");
	Class optionsClass = NSClassFromString(@"NCMutableNotificationOptions");
	if (!requestClass || !contentClass || !optionsClass) {
		return nil;
	}
	NSObject *notificationContent = [[contentClass alloc] init];
	[notificationContent safelySetValue:title forKey:@"title"];
	[notificationContent safelySetValue:message forKey:@"message"];
	[notificationContent safelySetValue:[NSDate date] forKey:@"date"];
	NSObject *options = [[optionsClass alloc] init];
	NSObject *request = [[requestClass alloc] init];
	[request safelySetValue:sectionIdentifier forKey:@"sectionIdentifier"];
	[request safelySetValue:@"shortlook-demo" forKey:@"notificationIdentifier"];
	[request safelySetValue:@"shortlook-demo" forKey:@"threadIdentifier"];
	[request safelySetValue:[NSDate date] forKey:@"timestamp"];
	[request safelySetValue:destinations forKey:@"requestDestinations"];
	[request safelySetValue:notificationContent forKey:@"content"];
	[request safelySetValue:options forKey:@"options"];
	return (NCNotificationRequest *)request;
}

- (void)clearDemoNotifications {
	for (NCNotificationRequest *request in sentNotifications) {
		@try {
			[[(SpringBoard *)[UIApplication sharedApplication] notificationDispatcher].dispatcher withdrawNotificationWithRequest:request];
		} @catch (NSException *exception) {
		}
	}
	sentNotifications = [NSMutableArray array];
}

- (NSString *)randomBundleIdentifier {
	NSMutableArray *bundleIdentifiers = [[[NSClassFromString(@"SBApplicationController") sharedInstance] allBundleIdentifiers] mutableCopy];
	if ([NSClassFromString(@"SBApplicationController") respondsToSelector:@selector(alwaysAvailableApplicationBundle)]) {
		[bundleIdentifiers removeObjectsInArray:[NSClassFromString(@"SBApplicationController") alwaysAvailableApplicationBundle]];
	}
	if (bundleIdentifiers.count == 0) return @"com.apple.Preferences";
	return [bundleIdentifiers objectAtIndex:arc4random_uniform((u_int32_t)bundleIdentifiers.count)];
}

@end
