#import "DDBaseSettingsController.h"
#import "DDSettingsNavigationTitleView.h"

@interface DDSettingsController : DDBaseSettingsController <UIScrollViewDelegate>
@property (nonatomic, assign) BOOL themedStatusBar;
@property (nonatomic, assign, setter=set_navbarEffectActive:) BOOL _navbarEffectActive;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) DDSettingsNavigationTitleView *titleView;
@property (nonatomic, assign) UIStatusBarStyle originalStatusBarStyle;
- (void)adjustForNavigationBarMode;
- (void)openDynasticWebsite:(id)sender;
- (void)setNavbarEffectActive:(BOOL)active;
- (void)didScroll;
- (NSString *)copyrightText;
- (NSString *)copyrightYearText;
- (void)notificationButtonPerformedAction:(PSSpecifier *)specifier;
@end
