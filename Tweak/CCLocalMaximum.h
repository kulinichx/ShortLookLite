//
//  CCLocalMaximum.h
//  Colorcube
//
//  Created by Ole Krause-Sparmann on 16.11.12.
//  Copyright (c) 2012 pixelogik. All rights reserved.
//  MIT License
//

#import <Foundation/Foundation.h>

// Describes a color cube cell that is a local maximum
@interface CCLocalMaximum : NSObject

// Hit count of the cell
@property (assign, nonatomic) unsigned int hitCount;

// Linear index of the cell
@property (assign, nonatomic) unsigned int cellIndex;

// Average color of cell
@property (assign, nonatomic) double red;
@property (assign, nonatomic) double green;
@property (assign, nonatomic) double blue;

// Maximum color component value of average color
@property (assign, nonatomic) double brightness;

@end
