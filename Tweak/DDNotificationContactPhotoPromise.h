#import <UIKit/UIKit.h>
#import "DDNotificationContactPhotoSettings.h"

@interface DDNotificationContactPhotoPromise : NSObject
@property (nonatomic, copy) NSMutableArray *callbacks;
@property (nonatomic, retain) DDNotificationContactPhotoSettings *settings;
@property (nonatomic, readonly, assign) BOOL isComplete;
- (void)resolveWithImage:(UIImage *)image;
- (void)reject;
- (void)registerForUpdatesWithHandler:(void (^)(UIImage *image))handler;
@end
