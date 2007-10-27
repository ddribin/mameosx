//
//  MameInputDevice.h
//  mameosx
//
//  Created by Dave Dribin on 10/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DDHidDevice;

@interface MameInputDevice : NSObject
{
    @protected
    DDHidDevice * mDevice;
    int mMameTag;
    BOOL mEnabled;
}

- (id) initWithDevice: (DDHidDevice *) device mameTag: (int) mameTag;

- (void) osd_init;

- (void) gameFinished;

- (BOOL) tryStartListening;

- (void) stopListening;

- (BOOL) enabled;
- (void) setEnabled: (BOOL) flag;

@end
