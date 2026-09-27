// ShortLook Lite — 全屏大头像视图
#import "SLLCommon.h"

@interface SLLOverlayView : UIView
@property (nonatomic, copy) void (^onDismissRequest)(NSString *reason);
@property (nonatomic, assign) BOOL showsClock;
- (void)setName:(NSString *)name message:(NSString *)message appIcon:(UIImage *)appIcon;
- (void)setMessageHidden:(BOOL)hidden;
- (void)setAvatar:(UIImage *)avatar isAppIcon:(BOOL)isAppIcon animated:(BOOL)animated;
- (void)refreshClock;
@end
