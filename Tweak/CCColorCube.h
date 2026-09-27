//
//  CCColorCube.h
//  Colorcube
//
//  Created by Ole Krause-Sparmann on 15.11.12.
//  Copyright (c) 2012 pixelogik. All rights reserved.
//  MIT License
//

#import <UIKit/UIKit.h>

// Flags that determine how the colors are extract
typedef enum CCFlags: NSUInteger {
	// This ignores all pixels that are darker than a threshold
	CCOnlyBrightColors   = 1 << 0,

	// This ignores all pixels that are brighter than a threshold
	CCOnlyDarkColors     = 1 << 1,

	// This filters the result array so that only distinct colors are returned
	CCOnlyDistinctColors = 1 << 2,

	// This orders the result array by color brightness (first color has highest brightness). If not set,
	// colors are ordered by frequency (first color is "most frequent").
	CCOrderByBrightness  = 1 << 3,

	// This orders the result array by color darkness (first color has lowest brightness). If not set,
	// colors are ordered by frequency (first color is "most frequent").
	CCOrderByDarkness    = 1 << 4,

	// Removes colors from the result if they are too close to white
	CCAvoidWhite         = 1 << 5,

	// Removes colors from the result if they are too close to black
	CCAvoidBlack         = 1 << 6
} CCFlags;

// The color cube is made out of these cells
typedef struct CCCubeCell {
	// Count of hits (dividing the accumulators by this value gives the average)
	unsigned int hitCount;

	// Accumulators for color components
	double redAcc;
	double greenAcc;
	double blueAcc;
} CCCubeCell;

// This class implements a simple method to extract the most dominant colors of an image.
@interface CCColorCube : NSObject

// Extracts and returns dominant colors of the image (the array contains UIColor objects).
- (NSArray *)extractColorsFromImage:(UIImage *)image flags:(NSUInteger)flags;

// Same as above but avoids colors too close to the specified one.
- (NSArray *)extractColorsFromImage:(UIImage *)image flags:(NSUInteger)flags avoidColor:(UIColor *)avoidColor;

// Tries to get count bright colors from the image, avoiding the specified one (only if avoidColor is non-nil).
- (NSArray *)extractBrightColorsFromImage:(UIImage *)image avoidColor:(UIColor *)avoidColor count:(NSUInteger)count;

// Tries to get count dark colors from the image, avoiding the specified one (only if avoidColor is non-nil).
- (NSArray *)extractDarkColorsFromImage:(UIImage *)image avoidColor:(UIColor *)avoidColor count:(NSUInteger)count;

// Tries to get count colors from the image
- (NSArray *)extractColorsFromImage:(UIImage *)image flags:(NSUInteger)flags count:(NSUInteger)count;

@end
