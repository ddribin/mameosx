//
//  MameInputDevice.m
//  mameosx
//
//  Created by Dave Dribin on 10/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MameInputDevice.h"

@implementation MameInputDevice

- (id) initWithDevice: (DDHidDevice *) device mameTag: (int) mameTag;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mDevice = [device retain];
    mMameTag = mameTag;
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mDevice release];
    
    mDevice = nil;
    [super dealloc];
}

- (void) osd_init;
{
}

- (void) gameFinished;
{
    [mDevice stopListening];
}

- (BOOL) tryStartListening;
{
    BOOL success = NO;
    @try
    {
        [mDevice startListening];
        success = YES;
    }
    @catch (id e)
    {
        JRLogInfo(@"tryStartListening exception: %@", e);
        success = NO;
    }
    return success;
}

- (void) stopListening;
{
    [mDevice stopListening];
}

//=========================================================== 
//  enabled 
//=========================================================== 
- (BOOL) enabled
{
    return mEnabled;
}

- (void) setEnabled: (BOOL) flag
{
    mEnabled = flag;
}

@end
