#import <UIKit/UIKit.h>

@class NCNotificationRequest;

@interface DDApplication : NSObject
+ (instancetype)applicationFromNotificationRequest:(NCNotificationRequest *)request;
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon identifier:(NSString *)identifier;
- (UIColor *)iconTintColour;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) UIImage *icon;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) BOOL allowsPreciseIconTransition;
@property (nonatomic, assign) BOOL usesInnerIconAppearance;
@end
