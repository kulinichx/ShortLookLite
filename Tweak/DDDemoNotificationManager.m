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
	NCNotificationRequest *request = [self notificationRequestForTitle:@"Hello from ShortLook!" content:@"This is a test notification from ShortLook." fromApplicationIdentifier:[self randomBundleIdentifier]];
	[[(SpringBoard *)[UIApplication sharedApplication] notificationDispatcher].dispatcher postNotificationWithRequest:request];
	[sentNotifications addObject:request];
}

- (NCNotificationRequest *)notificationRequestForTitle:(NSString *)title content:(NSString *)content fromApplicationIdentifier:(NSString *)applicationIdentifier {
	NCNotificationRequest *request = [NSClassFromString(@"NCNotificationRequest") notificationRequestWithSectionId:applicationIdentifier notificationId:@"shortlook-demo" threadId:@"shortlook-demo" title:title message:content timestamp:[NSDate date] destinations:[NSSet setWithObjects:@"BulletinDestinationCoverSheet", @"BulletinDestinationNotificationCenter", @"BulletinDestinationLockScreen", nil]];
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

- (void)clearDemoNotifications {
	for (NCNotificationRequest *request in sentNotifications) {
		[[(SpringBoard *)[UIApplication sharedApplication] notificationDispatcher].dispatcher withdrawNotificationWithRequest:request];
	}
	sentNotifications = [NSMutableArray array];
}

- (NSString *)randomBundleIdentifier {
	NSMutableArray *bundleIdentifiers = [[[NSClassFromString(@"SBApplicationController") sharedInstance] allBundleIdentifiers] mutableCopy];
	[bundleIdentifiers removeObjectsInArray:[NSClassFromString(@"SBApplicationController") alwaysAvailableApplicationBundle]];
	return [bundleIdentifiers objectAtIndex:arc4random_uniform((u_int32_t)bundleIdentifiers.count)];
}

@end
