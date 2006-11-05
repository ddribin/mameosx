//
//  MameFilter.h
//  mameosx
//
//  Created by Dave Dribin on 11/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface MameFilter : NSObject
{
    CIFilter * mFilter;
    CIFilter * mCrop;
}

- (id) initWithFilter: (CIFilter *) filter;

+ (MameFilter *) filterWithFilter: (CIFilter *) filter;

- (CIImage *) filterFrame: (CIImage *) frame size: (NSSize) size;

@end

