#import <UIKit/UIKit.h>
#import "DDNotificationContactPhotoPromise.h"

@interface DDNotificationContactPhotoPromiseOffer : NSObject
@property (nonatomic, readonly, retain) NSString *photoIdentifier;
@property (nonatomic, retain) NSString *titleOverride;
@property (nonatomic, retain) NSString *subtitleOverride;
@property (nonatomic, retain) NSString *bodyOverride;
- (instancetype)initWithPhotoIdentifier:(NSString *)photoIdentifier;
+ (instancetype)offerDownloadingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier fromURL:(NSURL *)url;
+ (instancetype)offerDownloadingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier fromURL:(NSURL *)url withSettings:(DDNotificationContactPhotoSettings *)settings;
+ (instancetype)offerInstantlyResolvingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier image:(UIImage *)image;
+ (instancetype)offerInstantlyResolvingPromiseWithPhotoIdentifier:(NSString *)photoIdentifier image:(UIImage *)image withSettings:(DDNotificationContactPhotoSettings *)settings;
- (void)fulfillWithBlock:(void (^)(DDNotificationContactPhotoPromise *promise))block;
- (DDNotificationContactPhotoPromise *)generatePromise;
@end
