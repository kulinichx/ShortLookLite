// Preferences.framework private interfaces used by FloraSettings.
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PSCellType) {
	PSGroupCell,
	PSLinkCell,
	PSLinkListCell,
	PSListItemCell,
	PSTitleValueCell,
	PSSliderCell,
	PSSwitchCell,
	PSStaticTextCell,
	PSEditTextCell,
	PSSegmentCell,
	PSGiantIconCell,
	PSGiantCell,
	PSSecureEditTextCell,
	PSButtonCell,
	PSEditTextViewCell,
};

@interface PSSpecifier : NSObject {
@public
	SEL action;
}
@property (nonatomic, retain) NSMutableDictionary *properties;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) PSCellType cellType;
@property (nonatomic, assign) id target;
+ (instancetype)emptyGroupSpecifier;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
@end

@interface PSTableCell : UITableViewCell
+ (PSCellType)cellTypeFromString:(NSString *)string;
@end

@interface PSViewController : UIViewController
@property (nonatomic, retain) PSSpecifier *specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
@end

@interface PSListController : PSViewController <UITableViewDelegate, UITableViewDataSource> {
	NSMutableArray *_specifiers;
}
@property (nonatomic, retain) NSMutableArray *specifiers;
- (NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)plistName target:(id)target bundle:(NSBundle *)bundle;
- (UITableView *)table;
- (NSBundle *)bundle;
- (PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadSpecifiers;
- (void)clearCache;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
@end

@interface UIApplication (FloraPrivate)
- (void)_relaunchSpringBoardNow;
- (NSURL *)generateURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(NSUInteger)options targetURL:(NSURL *)targetURL;
@end

@interface SBSRestartRenderServerAction : NSObject
+ (instancetype)restartActionWithTargetRelaunchURL:(NSURL *)targetURL;
@end
