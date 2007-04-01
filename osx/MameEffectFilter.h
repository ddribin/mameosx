//
//  DDScale2xFilter.h
//  CIHazeFilterSample
//
//  Created by Dave Dribin on 3/6/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>


@interface MameEffectFilter : CIFilter
{
    CIImage * inputImage;
    CIImage * effectImage;
}

- (CIImage *) outputImage;

@end
