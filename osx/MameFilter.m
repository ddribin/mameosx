//
//  MameFilter.m
//  mameosx
//
//  Created by Dave Dribin on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MameFilter.h"


@implementation MameFilter

- (id) initWithFilter: (CIFilter *) filter;
{
    if ([super init] == nil)
        return nil;
    
    mFilter = [filter retain];
    mCrop = [[CIFilter filterWithName: @"CICrop"] retain];

    return self;
}

- (id) init
{
    return [self initWithFilter: nil];
}

+ (MameFilter *) filterWithFilter: (CIFilter *) filter;
{
    return [[[self alloc] initWithFilter: filter] autorelease];
}

- (void) dealloc;
{
    [mFilter release];
    [mCrop release];
    [super dealloc];
}

- (CIImage *) filterFrame: (CIImage *) frame size: (NSSize) size;
{
    if (mFilter == nil)
        return frame;

    [mFilter setValue: frame forKey:@"inputImage"];
    frame = [mFilter valueForKey: @"outputImage"];
    
    [mCrop setValue: frame forKey: @"inputImage"];
    [mCrop setValue: [CIVector vectorWithX: 0  Y: 0
                                         Z: size.width W: size.height]
                  forKey: @"inputRectangle"];
    frame = [mCrop valueForKey: @"outputImage"];
    return frame;
}

@end
