#import "DDCoalescedNotification.h"
#import "DDAbstractNotification.h"
#import "DDUserNotification.h"
#import "DDNotificationContactPhotoProviderManager.h"

@implementation DDCoalescedNotification

- (instancetype)initWithNotifications:(NSArray *)notifications {
	if ((self = [super init])) {
		_notifications = notifications;
	}
	return self;
}

- (DDApplication *)application {
	return [(DDAbstractNotification *)_notifications.firstObject application];
}

- (NSString *)title {
	NSString *commonTitle = nil;
	for (DDAbstractNotification *notification in _notifications) {
		if (![notification hasCustomTitle] || (commonTitle && ![commonTitle isEqualToString:[notification title]])) {
			NSString *count = [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithUnsignedInteger:_notifications.count] numberStyle:NSNumberFormatterDecimalStyle];
			return [NSString stringWithFormat:@"%@ Notification%@", count, _notifications.count == 1 ? @"" : @"s"];
		}
		commonTitle = [notification title];
	}
	return commonTitle;
}

- (NSString *)subtitle {
	NSString *commonSubtitle = nil;
	for (DDAbstractNotification *notification in _notifications) {
		if (![notification hasCustomSubtitle] || (commonSubtitle && ![commonSubtitle isEqualToString:[notification subtitle]])) {
			return nil;
		}
		commonSubtitle = [notification subtitle];
	}
	return commonSubtitle;
}

- (NSString *)senderTitle {
	return [[self application] title];
}

- (UIImage *)icon {
	return [[self application] icon];
}

- (NSString *)badge {
	NSInteger count = _notifications.count;
	if (count < 1000) return [NSString stringWithFormat:@"%ld", (long)count];
	return [NSString stringWithFormat:@"%ld+", (long)MIN(count, 999)];
}

- (NSString *)senderIdentifier {
	return [[self application] identifier];
}

- (UIColor *)tintColour {
	return [[self application] iconTintColour];
}

- (BOOL)allowsPreciseIconTransition {
	for (NSObject<DDNotificationDisplayable> *notification in _notifications) {
		if (![notification allowsPreciseIconTransition]) return NO;
	}
	return YES;
}

- (NSObject<DDNotificationDisplayable> *)coalescedNotificationWithNotification:(NSObject<DDNotificationDisplayable> *)notification {
	return [[DDCoalescedNotification alloc] initWithNotifications:[_notifications arrayByAddingObject:notification]];
}

- (DDUserNotification *)userNotification {
	if (![self canProxyNotificationForContactPhoto]) return nil;
	return _notifications.lastObject;
}

- (BOOL)canProxyNotificationForContactPhoto {
	NSString *commonIdentifier = nil;
	for (id notification in _notifications) {
		if (![notification isKindOfClass:[DDUserNotification class]]) return NO;
		NSString *identifier = [[DDNotificationContactPhotoProviderManager sharedManager] contactPhotoIdentifierForUserNotification:notification];
		if (!identifier || (commonIdentifier && ![commonIdentifier isEqualToString:identifier])) return NO;
		commonIdentifier = identifier;
	}
	return YES;
}

- (NSString *)description {
	NSMutableArray *descriptions = [NSMutableArray array];
	for (id notification in _notifications) {
		[descriptions addObject:[notification description]];
	}
	return [NSString stringWithFormat:@"%@[%lu COALESCED ITEMS]((%@))", [super description], (unsigned long)_notifications.count, [descriptions componentsJoinedByString:@", "]];
}

@end
