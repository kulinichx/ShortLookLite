#import <UIKit/UIKit.h>

@interface UIColor (EasyDynamic)
+ (UIColor *)dynamicColorWithLightVariant:(UIColor *)lightVariant darkVariant:(UIColor *)darkVariant;
+ (UIColor *)_colorFromDDString:(NSString *)string;
+ (UIColor *)colorForKey:(NSString *)key fromDictionary:(NSDictionary *)dictionary;
@end
