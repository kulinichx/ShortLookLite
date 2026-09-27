#import <UIKit/UIKit.h>

@interface DDApplicationColourAnalyzer : NSObject
+ (instancetype)sharedAnalyzer;
- (UIColor *)idealColourForImage:(UIImage *)image withIdentifier:(NSString *)identifier;
@end
