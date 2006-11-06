//
//  CustomMameFilters.m
//  mameosx
//
//  Created by Dave Dribin on 11/6/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "CustomMameFilters.h"


@implementation MameInputCenterFilter

- (id) initWithFilter: (CIFilter *) filter;
{
    if ([super initWithFilter: filter] == nil)
        return nil;
    
    return self;
}

+ (MameInputCenterFilter *) filterWithFilter: (CIFilter *) filter;
{
    return [[[self alloc] initWithFilter: filter] autorelease];
}

- (CIImage *) filterFrame: (CIImage *) inputImage size: (NSSize) size;
{
    [mFilter setValue: [CIVector vectorWithX: size.width/2 Y: size.height/2]
               forKey: @"inputCenter"];
    return [super filterFrame: inputImage size: size];
}

@end



@implementation MameBumpDistortionFilter

- (id) init;
{
    if ([super initWithFilter: [CIFilter filterWithName: @"CIBumpDistortion"]] == nil)
        return nil;
    
    [mFilter setDefaults];
    [mFilter setValue: [NSNumber numberWithFloat: 75]  
               forKey: @"inputRadius"];
    [mFilter setValue: [NSNumber numberWithFloat:  3.0]  
               forKey: @"inputScale"];
    mCenterX = 0;
    
    return self;
}

+ (MameBumpDistortionFilter *) filter;
{
    return [[[self alloc] init] autorelease];
}

- (CIImage *) filterFrame: (CIImage *) frame size: (NSSize) size;
{
    mCenterX += 2;
    if (mCenterX > (size.width - 0))
        mCenterX = 0;
    
    [mFilter setValue: [CIVector vectorWithX: mCenterX Y: size.height/2]
               forKey: @"inputCenter"];
    return [super filterFrame: frame size: size];
}

@end
