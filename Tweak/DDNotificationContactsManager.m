#import "DDNotificationContactsManager.h"
#import <Contacts/Contacts.h>
#import "Private.h"

@implementation DDNotificationContactsManager {
	CNContactStore *store;
	NSMutableDictionary *allContactPhotosByIdentifiers;
	NSMutableDictionary *allContactIdentifiersByAliases;
	NSDateComponents *_userBirthday;
}

+ (instancetype)sharedManager {
	static DDNotificationContactsManager *sharedManager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

- (instancetype)init {
	if ((self = [super init])) {
		store = [[CNContactStore alloc] init];
	}
	return self;
}

- (void)loadAllContactPhotosIfNeeded {
	if (allContactPhotosByIdentifiers) return;
	allContactPhotosByIdentifiers = [NSMutableDictionary dictionary];
	allContactIdentifiersByAliases = [NSMutableDictionary dictionary];
	CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:@[CNContactImageDataKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey]];
	[store enumerateContactsWithFetchRequest:request error:nil usingBlock:^(CNContact *contact, BOOL *stop) {
		if (![contact isKeyAvailable:CNContactImageDataKey]) return;
		self->allContactPhotosByIdentifiers[contact.identifier] = contact.imageData;
		if ([contact isKeyAvailable:CNContactPhoneNumbersKey]) {
			[contact.phoneNumbers enumerateObjectsUsingBlock:^(CNLabeledValue<CNPhoneNumber *> *phoneNumber, NSUInteger idx, BOOL *stop2) {
				NSString *number = [phoneNumber.value unformattedInternationalStringValue];
				if (number) self->allContactIdentifiersByAliases[number] = contact.identifier;
			}];
		}
		if ([contact isKeyAvailable:CNContactEmailAddressesKey]) {
			[contact.emailAddresses enumerateObjectsUsingBlock:^(CNLabeledValue<NSString *> *emailAddress, NSUInteger idx, BOOL *stop2) {
				self->allContactIdentifiersByAliases[[emailAddress.value lowercaseString]] = contact.identifier;
			}];
		}
	}];
}

- (NSString *)contactIdentifierFromPossibleAlias:(NSString *)alias {
	if (allContactPhotosByIdentifiers[alias]) return alias;
	NSString *identifier = allContactIdentifiersByAliases[[alias lowercaseString]];
	if (identifier) return identifier;
	NSString *number = [[CNPhoneNumber phoneNumberWithStringValue:alias] unformattedInternationalStringValue];
	if (!number) return nil;
	return allContactIdentifiersByAliases[number];
}

- (UIImage *)contactPhotoFromContactIdentifier:(NSString *)identifier {
	[self loadAllContactPhotosIfNeeded];
	NSData *data = allContactPhotosByIdentifiers[[self contactIdentifierFromPossibleAlias:identifier]];
	if (!data) return nil;
	return [UIImage imageWithData:data];
}

- (CNContact *)userContactWithKeysToFetch:(NSArray *)keys {
	return [store _ios_meContactWithKeysToFetch:keys error:nil];
}

- (NSDateComponents *)userBirthday {
	if (!_userBirthday) {
		_userBirthday = [[self userContactWithKeysToFetch:@[CNContactBirthdayKey]] birthday];
	}
	return _userBirthday;
}

- (BOOL)isTodayUsersBirthday {
	NSDateComponents *birthday = [self userBirthday];
	if (!birthday) return NO;
	NSDateComponents *today = [birthday.calendar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate date]];
	return today.month == birthday.month && today.day == birthday.day;
}

@end
