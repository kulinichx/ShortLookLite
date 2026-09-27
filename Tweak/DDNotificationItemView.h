#import <UIKit/UIKit.h>
#import "DDNotificationProtocols.h"
#import "DDNotificationIconContainerView.h"

@interface DDNotificationItemView : UIView
- (void)setNotification:(NSObject<DDNotificationDisplayable> *)notification animated:(BOOL)animated;
- (void)setNotification:(NSObject<DDNotificationDisplayable> *)notification animated:(BOOL)animated bounces:(BOOL)bounces;
- (void)bounce;
- (void)animateIconToFrame:(CGRect)frame inView:(UIView *)view;
@property (nonatomic, retain) DDNotificationIconContainerView *iconView;
@property (nonatomic, retain) NSObject<DDNotificationDisplayable> *notification;
@property (nonatomic, assign) BOOL truncatesLongNotificationBodies;
@end
