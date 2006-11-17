/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

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

