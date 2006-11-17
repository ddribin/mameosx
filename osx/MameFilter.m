/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

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
