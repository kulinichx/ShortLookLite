#import "DDSettingsSubController.h"

@implementation DDSettingsSubController

- (NSMutableArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:[self plistName] target:self bundle:[self preferencesBundle]];
	}
	return _specifiers;
}

- (NSBundle *)preferencesBundle {
	return [(DDBaseSettingsController *)[[self specifier] target] preferencesBundle];
}

- (NSString *)plistName {
	if ([[self specifier] properties][@"Plist"]) {
		return [[self specifier] properties][@"Plist"];
	}
	return [[self specifier] identifier];
}

@end
