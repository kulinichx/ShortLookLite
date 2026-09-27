#import <UIKit/UIKit.h>

@interface DDNotificationContactsManager : NSObject
+ (instancetype)sharedManager;
- (void)loadAllContactPhotosIfNeeded;
- (NSString *)contactIdentifierFromPossibleAlias:(NSString *)alias;
- (UIImage *)contactPhotoFromContactIdentifier:(NSString *)identifier;
- (NSDateComponents *)userBirthday;
- (BOOL)isTodayUsersBirthday;
@end
