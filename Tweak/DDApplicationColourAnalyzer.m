#import "DDApplicationColourAnalyzer.h"
#import "CCColorCube.h"

@implementation DDApplicationColourAnalyzer {
	CCColorCube *colourAnalyzer;
	NSMutableDictionary *cachedColours;
}

+ (instancetype)sharedAnalyzer {
	static DDApplicationColourAnalyzer *sharedAnalyzer;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedAnalyzer = [[self alloc] init];
	});
	return sharedAnalyzer;
}

- (instancetype)init {
	if ((self = [super init])) {
		colourAnalyzer = [[CCColorCube alloc] init];
		// Note: the original never allocates cachedColours, so colours are never actually cached.
	}
	return self;
}

- (UIColor *)idealColourForImage:(UIImage *)image withIdentifier:(NSString *)identifier {
	UIColor *colour = cachedColours[identifier];
	if (colour) return colour;
	if (!image) return nil;
	NSArray *colours = [colourAnalyzer extractColorsFromImage:image flags:CCOnlyDistinctColors | CCAvoidWhite | CCAvoidBlack count:1];
	colour = colours.count ? colours[0] : nil;
	if (colour && identifier) cachedColours[identifier] = colour;
	return colour;
}

@end
