#import "UIColor+EasyDynamic.h"

@implementation UIColor (EasyDynamic)

+ (UIColor *)dynamicColorWithLightVariant:(UIColor *)lightVariant darkVariant:(UIColor *)darkVariant {
	if (darkVariant) {
		if (@available(iOS 13, *)) {
			return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
				return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkVariant : lightVariant;
			}];
		}
	}
	return lightVariant;
}

+ (UIColor *)_colorFromDDString:(NSString *)string {
	NSArray *components = [string componentsSeparatedByString:@":"];
	return [UIColor colorWithRed:[components[0] floatValue] green:[components[1] floatValue] blue:[components[2] floatValue] alpha:1.0];
}

+ (UIColor *)colorForKey:(NSString *)key fromDictionary:(NSDictionary *)dictionary {
	if (!dictionary[key]) return nil;
	UIColor *lightVariant = [self _colorFromDDString:[dictionary[key] stringValue]];
	if (!lightVariant) return nil;
	NSString *darkKey = [key stringByAppendingString:@":dark"];
	UIColor *darkVariant = dictionary[darkKey] ? [self _colorFromDDString:[dictionary[darkKey] stringValue]] : nil;
	return [self dynamicColorWithLightVariant:lightVariant darkVariant:darkVariant];
}

@end
