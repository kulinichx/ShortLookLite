#import <UIKit/UIKit.h>
#import "DDNotificationContactPhotoProviderCachedItem.h"

@interface DDNotificationContactPhotoProviderCache : NSObject
- (void)addContactPhoto:(UIImage *)contactPhoto andSettings:(DDNotificationContactPhotoSettings *)settings withIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier;
- (DDNotificationContactPhotoProviderCachedItem *)cachedItemWithIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier;
- (BOOL)hasCachedItemWithIdentifier:(NSString *)identifier forSenderIdentifier:(NSString *)senderIdentifier;
- (void)clearCache;
@end
