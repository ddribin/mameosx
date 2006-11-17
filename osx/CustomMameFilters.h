/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <MameKit/MameKit.h>


@interface MameInputCenterFilter : MameFilter
{
}

- (id) initWithFilter: (CIFilter *) filter;
+ (MameInputCenterFilter *) filterWithFilter: (CIFilter *) filter;

@end

@interface MameBumpDistortionFilter : MameFilter
{
    float mCenterX;
}

- (id) init;
+ (MameBumpDistortionFilter *) filter;

@end
