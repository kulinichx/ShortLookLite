#import "DDUserNotification.h"
#import "DDNotificationViewSettings.h"

@implementation DDUserNotification

- (instancetype)initWithNotificationRequest:(NCNotificationRequest *)request {
	if ([[request.sectionIdentifier lowercaseString] isEqualToString:@"com.laughingquoll.maple"]) return nil;
	BOOL canShowSupressedContent = [DDUserNotification canShowSupressedContent];
	BOOL showTitle = canShowSupressedContent || !request.options.suppressesTitleWhenLocked;
	BOOL showSubtitle = canShowSupressedContent || !request.options.suppressesSubtitleWhenLocked;
	BOOL showBody = NO;
	if (canShowSupressedContent || !request.options.suppressesBodyWhenLocked) {
		showBody = [DDNotificationViewSettings sharedSettings].showNotificationBody;
	}
	NSString *title = showTitle ? request.content.title : nil;
	NSString *subtitle = showSubtitle ? request.content.subtitle : nil;
	NSString *body = showBody ? request.content.message : nil;
	DDApplication *application = [DDApplication applicationFromNotificationRequest:request];
	if ((self = [super initWithNotificationTitle:title notificationSubtitle:subtitle notificationBody:body application:application])) {
		_request = request;
	}
	return self;
}

- (UNNotificationContent *)content {
	return _request.userNotification.request.content;
}

- (BOOL)isSupressingContentForUnlock {
	return _request.options.suppressesTitleWhenLocked || _request.options.suppressesSubtitleWhenLocked || _request.options.suppressesBodyWhenLocked;
}

+ (BOOL)canShowSupressedContent {
	Class managerClass = NSClassFromString(@"SBLockScreenManager");
	if (!managerClass) return NO;
	return [[[managerClass sharedInstance] _userAuthController] _isUserAuthenticated];
}

- (NSDictionary *)applicationUserInfo {
	return [self content].userInfo;
}

- (NSObject<DDNotificationRefreshable> *)refreshedNotification {
	return [[DDUserNotification alloc] initWithNotificationRequest:_request];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@<<%@>>", [super description], [self applicationUserInfo]];
}

@end
