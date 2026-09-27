#import <UIKit/UIKit.h>

@interface DDSettingsNavigationTitleView : UIView
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, assign) BOOL showingIcon;
@property (nonatomic, assign) BOOL whiteText;
- (void)setShowingIcon:(BOOL)showingIcon animated:(BOOL)animated;
@end
