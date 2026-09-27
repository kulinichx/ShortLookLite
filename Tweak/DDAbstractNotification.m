#import "DDAbstractNotification.h"
#import "DDCoalescedNotification.h"

@implementation DDAbstractNotification

- (instancetype)initWithNotificationTitle:(NSString *)notificationTitle application:(DDApplication *)application {
	return [self initWithNotificationTitle:notificationTitle notificationSubtitle:nil notificationBody:nil application:application];
}

- (instancetype)initWithNotificationTitle:(NSString *)notificationTitle notificationSubtitle:(NSString *)notificationSubtitle notificationBody:(NSString *)notificationBody application:(DDApplication *)application {
	if ((self = [super init])) {
		_notificationTitle = notificationTitle;
		_notificationSubtitle = notificationSubtitle;
		_notificationBody = notificationBody;
		_application = application;
	}
	return self;
}

- (BOOL)hasCustomTitle {
	NSString *title = __titleOverride ?: _notificationTitle;
	return title && title.length;
}

- (BOOL)hasCustomSubtitle {
	return [self subtitle] != nil;
}

- (NSString *)title {
	if ([self hasCustomTitle]) {
		NSString *title = __titleOverride ?: _notificationTitle;
		if (title && title.length) return title;
	}
	if ([self hasCustomSubtitle]) return [self subtitle];
	return [_application title];
}

- (NSString *)subtitle {
	return __subtitleOverride ?: _notificationSubtitle;
}

- (NSString *)body {
	NSString *body = __bodyOverride ?: _notificationBody;
	return body.length ? body : nil;
}

- (NSString *)senderTitle {
	if (![self hasCustomTitle] && ![self hasCustomSubtitle]) return nil;
	return [_application title];
}

- (UIImage *)icon {
	return [_application icon];
}

- (NSString *)senderIdentifier {
	return [_application identifier];
}

- (UIColor *)tintColour {
	return [_application iconTintColour];
}

- (BOOL)allowsPreciseIconTransition {
	return [_application allowsPreciseIconTransition];
}

- (NSObject<DDNotificationDisplayable> *)coalescedNotificationWithNotification:(NSObject<DDNotificationDisplayable> *)notification {
	return [[DDCoalescedNotification alloc] initWithNotifications:@[self, notification]];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@[t: %@, s: %@, b: %@, sdt: %@, sdi: %@]", [super description], [self title], [self subtitle], [self body], [self senderTitle], [self senderIdentifier]];
}

@end
