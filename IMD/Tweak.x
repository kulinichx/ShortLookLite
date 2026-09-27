#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

@interface CNContact : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@end

@interface IMDNotificationsController : NSObject
@end

%hook IMDNotificationsController

- (void)_populateUserInfoForMessageContent:(UNMutableNotificationContent *)content messageDictionary:(NSDictionary *)messageDictionary messageIsAddressedToMe:(BOOL)addressedToMe {
	%orig;
	CNContact *contact = [messageDictionary objectForKeyedSubscript:@"__kmessageCNContactForSenderKey"];
	if (contact) {
		NSMutableDictionary *userInfo = [content.userInfo mutableCopy];
		[userInfo setObject:contact.identifier forKey:@"DDSLAppleIsTerribleContactID"];
		[content setUserInfo:userInfo];
	}
}

%end
