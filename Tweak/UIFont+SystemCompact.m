#import "UIFont+SystemCompact.h"
#include <dlfcn.h>

@interface UIFont (SystemCompactPrivate)
+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight design:(NSString *)design;
@end

static NSString * __strong *DDSystemFontDesignAlternate;

@implementation UIFont (SystemCompact)

+ (void)load {
	DDSystemFontDesignAlternate = (NSString * __strong *)dlsym(RTLD_DEFAULT, "UIFontSystemFontDesignAlternate");
	if (!DDSystemFontDesignAlternate) {
		DDSystemFontDesignAlternate = (NSString * __strong *)dlsym(RTLD_DEFAULT, "_UIFontSystemFontDesignAlternate");
	}
}

+ (UIFont *)compactSystemFontOfSize:(CGFloat)size {
	return [self compactSystemFontOfSize:size weight:UIFontWeightRegular];
}

+ (UIFont *)compactSystemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
	return [UIFont systemFontOfSize:size weight:weight design:*DDSystemFontDesignAlternate];
}

@end
