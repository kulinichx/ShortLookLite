#import <UIKit/UIKit.h>

@interface DDNotificationViewSettings : NSObject
+ (instancetype)sharedSettings;
@property (nonatomic, retain) UIImage *iconMaskImage;
@property (nonatomic, retain) UIImage *defaultIconImage;
@property (nonatomic, retain) UIFont *notificationTitleFont;
@property (nonatomic, retain) UIFont *notificationSubtitleFont;
@property (nonatomic, retain) UIFont *notificationSenderTitleFont;
@property (nonatomic, retain) UIFont *notificationBodyFont;
@property (nonatomic, retain) UIFont *notificationFootnoteFont;
@property (nonatomic, retain) UIFont *notificationBadgeFont;
@property (nonatomic, retain) UIImage *welcomeNotificationImage;
@property (nonatomic, assign) NSTimeInterval timeUntilDismiss;
@property (nonatomic, assign) double animationDurationMultiplier;
@property (nonatomic, assign) BOOL loadContactPhotos;
@property (nonatomic, retain) Class backgroundViewProviderClass;
@property (nonatomic, retain) Class dismissAnimationProviderClass;
@property (nonatomic, assign) BOOL showNotificationBody;
@property (nonatomic, assign) BOOL hideNotificationIcon;
@property (nonatomic, assign) BOOL showSpecialEffects;
@end
