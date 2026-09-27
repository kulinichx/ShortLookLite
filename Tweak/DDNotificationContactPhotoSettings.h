#import <UIKit/UIKit.h>

@interface DDNotificationContactPhotoSettings : NSObject
+ (UIColor *)defaultBackgroundColor;
@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, assign) BOOL usesCaching;
@end
