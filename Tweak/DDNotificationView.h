#import <UIKit/UIKit.h>
#import "DDNotificationProtocols.h"

@interface DDNotificationView : UIView
- (NSObject<DDNotificationDisplayable> *)displayedNotification;
- (void)prepareForPresentation;
- (void)presentNotification:(NSObject<DDNotificationDisplayable> *)notification indefinitely:(BOOL)indefinitely;
- (void)refreshDisplayedNotification;
- (void)dismissForced:(BOOL)forced canUseTargetAnimation:(BOOL)canUseTargetAnimation allowsAnimateBackground:(BOOL)allowsAnimateBackground forSource:(DDNotificationDismissSource)source;
- (void)dismissForced:(BOOL)forced canUseTargetAnimation:(BOOL)canUseTargetAnimation allowsAnimateBackground:(BOOL)allowsAnimateBackground animationMultiplier:(double)animationMultiplier forSource:(DDNotificationDismissSource)source;
- (void)dismissForced:(BOOL)forced animationMultiplier:(double)animationMultiplier forSource:(DDNotificationDismissSource)source;
- (void)stopDismissTimer;
- (void)restartDismissTimer;
- (void)setBackgroundViewVisible:(BOOL)visible;
@property (nonatomic, weak) id<DDNotificationViewDelegate> delegate;
@end
