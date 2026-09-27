#import "DDNotificationContactPhotoProviderCachedItem.h"

@implementation DDNotificationContactPhotoProviderCachedItem

+ (instancetype)itemWithContactPhoto:(UIImage *)contactPhoto andSettings:(DDNotificationContactPhotoSettings *)settings {
	DDNotificationContactPhotoProviderCachedItem *item = [[DDNotificationContactPhotoProviderCachedItem alloc] init];
	item.contactPhoto = contactPhoto;
	item.settings = settings;
	return item;
}

@end
