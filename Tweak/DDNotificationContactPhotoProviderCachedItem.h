#import <UIKit/UIKit.h>
#import "DDNotificationContactPhotoSettings.h"

@interface DDNotificationContactPhotoProviderCachedItem : NSObject
+ (instancetype)itemWithContactPhoto:(UIImage *)contactPhoto andSettings:(DDNotificationContactPhotoSettings *)settings;
@property (nonatomic, retain) UIImage *contactPhoto;
@property (nonatomic, retain) DDNotificationContactPhotoSettings *settings;
@end
