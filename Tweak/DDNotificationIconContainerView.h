#import <UIKit/UIKit.h>
#import "DDNotificationIconView.h"
#import "DDNotificationContactImageView.h"
#import "DDNotificationBadgeView.h"

@class DDNotificationContactPhotoSettings;

@interface DDNotificationIconContainerView : UIView
@property (nonatomic, retain) DDNotificationIconView *iconImageView;
@property (nonatomic, retain) DDNotificationContactImageView *contactImageView;
@property (nonatomic, retain) DDNotificationBadgeView *badgeView;
@property (nonatomic, retain) UIImage *icon;
@property (nonatomic, assign) BOOL usesInnerIconAppearance;
@property (nonatomic, retain) UIImage *contactImage;
- (void)setContactImage:(UIImage *)contactImage withSettings:(DDNotificationContactPhotoSettings *)settings;
- (void)setContactImage:(UIImage *)contactImage withSettings:(DDNotificationContactPhotoSettings *)settings animated:(BOOL)animated;
@end
