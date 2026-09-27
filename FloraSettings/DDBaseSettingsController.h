#import "PSPrivate.h"

@interface DDBaseSettingsController : PSListController
@property (nonatomic, readonly, strong) UIColor *headerColour;
- (void)_loadSpecifiers;
- (void)URLSpecifierPerformedAction:(PSSpecifier *)specifier;
- (void)refreshSpecifiers;
- (void)reevaluateVisibilityAnimated:(BOOL)animated;
- (void)respringToSettings:(BOOL)toSettings;
- (NSURL *)_targetURL;
- (NSBundle *)preferencesBundle;
- (NSString *)tweakName;
- (NSString *)tweakVersion;
- (UIImage *)tweakIcon;
@end
