#import "DDBaseSettingsController.h"
#import "UIColor+EasyDynamic.h"
#import <objc/runtime.h>

@interface DDBaseSettingsController (FloraActions)
- (void)notificationButtonPerformedAction:(PSSpecifier *)specifier;
@end

@implementation DDBaseSettingsController {
	NSMutableDictionary *visibilityForDependedUponItems;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:[[self preferencesBundle] pathForResource:[self tweakName] ofType:@"plist"]];
	UIColor *tintColour = nil;
	if (plist) {
		_headerColour = [UIColor colorForKey:@"headerColour" fromDictionary:plist];
		tintColour = [UIColor colorForKey:@"tintColour" fromDictionary:plist];
	}
	if (!_headerColour) _headerColour = [UIColor colorWithRed:0.47 green:0.53 blue:0.97 alpha:1.0];
	if (!tintColour) tintColour = _headerColour;
	self.view.tintColor = tintColour;
	[UISwitch appearanceWhenContainedInInstancesOfClasses:@[[self class]]].onTintColor = tintColour;
	[UITextField appearanceWhenContainedInInstancesOfClasses:@[[self class]]].tintColor = tintColour;
	[UIButton appearanceWhenContainedInInstancesOfClasses:@[[self class]]].tintColor = tintColour;
	[UITextView appearanceWhenContainedInInstancesOfClasses:@[[self class]]].tintColor = tintColour;
	[UIStepper appearanceWhenContainedInInstancesOfClasses:@[[self class]]].tintColor = tintColour;
	[UISegmentedControl appearanceWhenContainedInInstancesOfClasses:@[[self class]]].tintColor = tintColour;
	[UISlider appearanceWhenContainedInInstancesOfClasses:@[[self class]]].tintColor = tintColour;
}

- (NSMutableArray *)specifiers {
	if (!_specifiers) [self _loadSpecifiers];
	return _specifiers;
}

- (void)_loadSpecifiers {
	NSMutableArray *specifiers = [self loadSpecifiersFromPlistName:[self tweakName] target:self bundle:[self preferencesBundle]];
	visibilityForDependedUponItems = [NSMutableDictionary dictionary];
	PSCellType buttonCellType = [PSTableCell cellTypeFromString:@"PSButtonCell"];
	NSMutableSet *dependedUponKeys = [NSMutableSet set];
	NSMutableDictionary *specifiersByKey = [NSMutableDictionary dictionary];
	for (PSSpecifier *specifier in specifiers) {
		NSDictionary *properties = specifier.properties;
		if (specifier.cellType == buttonCellType && properties[@"PostNotification"]) {
			specifier->action = @selector(notificationButtonPerformedAction:);
		}
		if (properties[@"DependsOn"] && [properties[@"DependsOn"] isKindOfClass:[NSString class]]) {
			[dependedUponKeys addObject:properties[@"DependsOn"]];
		}
		if (properties[@"key"] && [properties[@"key"] isKindOfClass:[NSString class]]) {
			specifiersByKey[properties[@"key"]] = specifier;
		}
	}
	for (NSString *key in [dependedUponKeys allObjects]) {
		BOOL visible = specifiersByKey[key] ? [[self readPreferenceValue:specifiersByKey[key]] boolValue] : NO;
		visibilityForDependedUponItems[key] = [NSNumber numberWithInt:visible];
	}
	_specifiers = specifiers;
}

- (void)URLSpecifierPerformedAction:(PSSpecifier *)specifier {
	NSString *urlString = [specifier propertyForKey:@"url"];
	if (!urlString) return;
	NSURL *url = [NSURL URLWithString:urlString];
	if (!url) return;
	[[UIApplication sharedApplication] openURL:url];
}

- (void)refreshSpecifiers {
	[self _loadSpecifiers];
	[self clearCache];
	[self reloadSpecifiers];
}

- (void)reevaluateVisibilityAnimated:(BOOL)animated {
	[[self table] beginUpdates];
	[[self table] endUpdates];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *dependsOn = [[self specifierAtIndexPath:indexPath] propertyForKey:@"DependsOn"];
	if (dependsOn && ![visibilityForDependedUponItems[dependsOn] boolValue]) return 0.01;
	return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	cell.clipsToBounds = YES;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	[super setPreferenceValue:value specifier:specifier];
	if ([specifier propertyForKey:@"key"] && [visibilityForDependedUponItems objectForKey:[specifier propertyForKey:@"key"]]) {
		visibilityForDependedUponItems[[specifier propertyForKey:@"key"]] = [NSNumber numberWithBool:[[self readPreferenceValue:specifier] boolValue]];
		[self reevaluateVisibilityAnimated:YES];
	}
	if ([[specifier propertyForKey:@"RespringRequired"] boolValue]) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Respring Required" message:@"This setting requires a respring in order to take effect. Would you like to restart SpringBoard now?" preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *respringAction = [UIAlertAction actionWithTitle:@"Respring Now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[self respringToSettings:YES];
		}];
		[alert addAction:respringAction];
		[alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
		alert.preferredAction = respringAction;
		[self presentViewController:alert animated:YES completion:nil];
	}
}

- (void)respringToSettings:(BOOL)toSettings {
	if (!objc_getClass("FBSSystemService")) {
		[[UIApplication sharedApplication] _relaunchSpringBoardNow];
		return;
	}
	NSURL *targetURL = toSettings ? [self _targetURL] : nil;
	id action = nil;
	if (objc_getClass("SBSRelaunchAction")) {
		action = [objc_getClass("SBSRelaunchAction") actionWithReason:@"RestartRenderServer" options:4 targetURL:targetURL];
	} else if (objc_getClass("SBSRestartRenderServerAction")) {
		action = [objc_getClass("SBSRestartRenderServerAction") restartActionWithTargetRelaunchURL:targetURL];
	}
	[[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:action] withResult:nil];
}

- (NSURL *)_targetURL {
	if (!objc_getClass("PreferencesAppController")) return nil;
	[[UIApplication sharedApplication] generateURL];
	return [NSURL URLWithString:(__bridge_transfer NSString *)CFPreferencesCopyAppValue(CFSTR("kPreferencePositionKey"), kCFPreferencesCurrentApplication)];
}

- (NSBundle *)preferencesBundle {
	NSString *bundleName = [NSString stringWithFormat:@"%@.bundle", [[self specifier] propertyForKey:@"bundle"]];
	return [NSBundle bundleWithURL:[[[[self bundle] bundleURL] URLByDeletingLastPathComponent] URLByAppendingPathComponent:bundleName]];
}

- (NSString *)tweakName {
	return [[[self preferencesBundle] infoDictionary] valueForKey:@"DDTweakName"];
}

- (NSString *)tweakVersion {
	return [[[self preferencesBundle] infoDictionary] valueForKey:@"CFBundleVersion"];
}

- (UIImage *)tweakIcon {
	return [UIImage imageNamed:@"icon" inBundle:[self preferencesBundle] compatibleWithTraitCollection:nil];
}

@end
