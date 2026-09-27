#import "DDNotificationSystemContactPhotoProvider.h"
#import "DDNotificationContactsManager.h"
#import "DDNotificationContactPhotoPromiseOffer.h"
#import "DDUserNotification.h"
#import "Private.h"

@implementation DDNotificationSystemContactPhotoProvider

- (instancetype)init {
	if ((self = [super init])) {
		[[[NSOperationQueue alloc] init] addOperationWithBlock:^{
			[[DDNotificationContactsManager sharedManager] loadAllContactPhotosIfNeeded];
		}];
	}
	return self;
}

- (DDNotificationContactPhotoPromiseOffer *)contactPhotoPromiseOfferForNotification:(DDUserNotification *)notification {
	NSString *contactID = [self contactIDForNotification:notification];
	if (!contactID) return nil;
	UIImage *image = [[DDNotificationContactsManager sharedManager] contactPhotoFromContactIdentifier:contactID];
	if (!image) return nil;
	DDNotificationContactPhotoSettings *settings = [[DDNotificationContactPhotoSettings alloc] init];
	settings.usesCaching = NO;
	return [DDNotificationContactPhotoPromiseOffer offerInstantlyResolvingPromiseWithPhotoIdentifier:contactID image:image withSettings:settings];
}

- (NSString *)contactIDForNotification:(DDUserNotification *)notification {
	if (notification.applicationUserInfo[@"contactInfo"]) return notification.applicationUserInfo[@"contactInfo"];
	NCNotificationRequest *request = notification.request;
	if ([request respondsToSelector:@selector(peopleIdentifiers)] && request.peopleIdentifiers && request.peopleIdentifiers.count) {
		return request.peopleIdentifiers.firstObject;
	}
	if ([request respondsToSelector:@selector(contactIdentifier)] && request.contactIdentifier) {
		return request.contactIdentifier;
	}
	return notification.applicationUserInfo[@"DDSLAppleIsTerribleContactID"] ?: nil;
}

@end
