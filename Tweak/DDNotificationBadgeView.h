#import <UIKit/UIKit.h>

@interface DDNotificationBadgeView : UIView
@property (nonatomic, assign, setter=setShowing:) BOOL isShowing;
@property (nonatomic, copy) NSString *text;
- (void)setText:(NSString *)text animated:(BOOL)animated;
@end
