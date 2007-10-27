//
//  MameKeyboard.h
//  mameosx
//
//  Created by Dave Dribin on 10/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MameInputDevice.h"

#define MAX_KEYS            256

@class DDHidKeyboard;

@interface MameKeyboard : MameInputDevice
{
    uint32_t mKeyStates[MAX_KEYS];
}

+ (NSArray *) allKeyboards;

- (void) osd_init;

- (uint32_t) getState: (int) key;

@end
