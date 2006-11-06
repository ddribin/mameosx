//
//  CustomMameFilters.h
//  mameosx
//
//  Created by Dave Dribin on 11/6/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

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
