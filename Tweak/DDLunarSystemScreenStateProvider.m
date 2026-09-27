#import "DDLunarSystemScreenStateProvider.h"
#import "Private.h"

@implementation DDLunarSystemScreenStateProvider

- (BOOL)isScreenOn {
	return [[[NSClassFromString(@"SBLockScreenManager") sharedInstance] valueForKey:@"_isScreenOn"] boolValue];
}

- (BOOL)isSystemScreenProvider {
	return YES;
}

@end
