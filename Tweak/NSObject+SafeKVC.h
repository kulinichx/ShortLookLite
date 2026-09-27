#import <Foundation/Foundation.h>

@interface NSObject (SafeKVC)
- (void)safelySetValue:(id)value forKey:(NSString *)key;
- (id)safeValueForKey:(NSString *)key;
@end
