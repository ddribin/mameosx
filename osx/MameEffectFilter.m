//
//  DDScale2xFilter.m
//  CIHazeFilterSample
//
//  Created by Dave Dribin on 3/6/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MameEffectFilter.h"


#define MAME_STANDALONE_FILTERS 1

static CIKernel * sMameEffectKernel = nil;

@implementation MameEffectFilter

#if MAME_STANDALONE_FILTERS
+ (void)initialize
{
    [CIFilter registerFilterName: @"MameEffectFilter"  constructor: self
                 classAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                     
                     @"Mame Image Effect Filter", kCIAttributeFilterDisplayName,
                     
                     [NSArray arrayWithObjects:
                         kCICategoryColorAdjustment, kCICategoryVideo, kCICategoryStillImage,
                         kCICategoryInterlaced, kCICategoryNonSquarePixels,
                         nil],                              kCIAttributeFilterCategories,
                     
                     [NSDictionary dictionaryWithObjectsAndKeys:
                         nil],                               @"effectImage",

                     nil]];
}

+ (CIFilter *)filterWithName: (NSString *)name
{
    CIFilter  *filter;
    
    filter = [[self alloc] init];
    return [filter autorelease];
}
#endif

- (id) init;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    if (sMameEffectKernel == nil)
    {
        NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
        NSString * kernelFile = [myBundle pathForResource: @"MameEffect"
                                                   ofType: @"cikernel"];
        NSString * code = [NSString stringWithContentsOfFile: kernelFile];
        NSArray * kernels = [CIKernel kernelsWithString: code];
        sMameEffectKernel = [[kernels objectAtIndex: 0] retain];
    }
    
    return self;
}

- (NSDictionary *) customAttributes;
{
    return [NSDictionary dictionary];
}

- (CIImage *) outputImage;
{
    NSDictionary * samplerOptions = [NSDictionary dictionaryWithObjectsAndKeys:
        kCISamplerFilterNearest, kCISamplerFilterMode,
        nil];
    CISampler * input = [CISampler samplerWithImage: inputImage
                                          options: samplerOptions];
    CISampler * effect = [CISampler samplerWithImage: effectImage
                                            options: samplerOptions];

    return [self apply: sMameEffectKernel, input, effect, @"definition",
        [input definition], nil];
}    

@end
