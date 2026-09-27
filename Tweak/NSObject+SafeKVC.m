#import "NSObject+SafeKVC.h"

@implementation NSObject (SafeKVC)

- (void)safelySetValue:(id)value forKey:(NSString *)key {
	@try {
		[self setValue:value forKey:key];
	} @catch (NSException *exception) {}
}

- (id)safeValueForKey:(NSString *)key {
	@try {
		return [self valueForKey:key];
	} @catch (NSException *exception) {
		return nil;
	}
}

@end
