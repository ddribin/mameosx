//
//  MameKeyboard.m
//  mameosx
//
//  Created by Dave Dribin on 10/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MameKeyboard.h"
#import "DDHidLib.h"

// MAME headers
#include "driver.h"

#include "MameInputTables.h"


@interface MameKeyboard (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;
@end

@implementation MameKeyboard

static INT32 keyboardGetState(void *device_internal, void *item_internal)
{
    MameKeyboard * keyboard = (MameKeyboard *) device_internal;
    int key = (int) item_internal;
    return [keyboard getState: key];
}

+ (NSArray *) allKeyboards;
{
    NSMutableArray * startedKeyboards = [NSMutableArray array];
    int keyboardTag = 0;
    NSArray * keyboards = [DDHidKeyboard allKeyboards];
    int keyboardCount = [keyboards count];
    int keyboardNumber;
    for (keyboardNumber = 0; keyboardNumber < keyboardCount; keyboardNumber++)
    {
        DDHidKeyboard * hidKeyboard = [keyboards objectAtIndex: keyboardNumber];
        JRLogInfo(@"Found keyboard: %@ (%@)",
                  [hidKeyboard productName], [hidKeyboard manufacturer]);
        MameKeyboard * keyboard = [[MameKeyboard alloc] initWithDevice: hidKeyboard
                                                               mameTag: keyboardTag];
        [keyboard autorelease];
        if ([keyboard tryStartListening])
        {
            [keyboard osd_init];
            [startedKeyboards addObject: keyboard];
            keyboardTag++;
        }
    }
    
    return startedKeyboards;
}

- (void) osd_init;
{
    DDHidKeyboard * keyboard = (DDHidKeyboard *) mDevice;
    [keyboard setDelegate: self];
    
    NSString * name = [NSString stringWithFormat: @"Keyboard %d", mMameTag];
    JRLogInfo(@"Adding keyboard device: %@", name);
    input_device * device = input_device_add(DEVICE_CLASS_KEYBOARD,
                                             [name UTF8String],
                                             self);
    
    
    int i = 0;
    while (sKeyboardTranslationTable[i].name != 0)
    {
        os_code_info * currentKey = &sKeyboardTranslationTable[i];
        input_device_item_add(device,
                              currentKey->name,
                              (void *) currentKey->oscode,
                              currentKey->itemId,
                              keyboardGetState);
        
        i++;
    }
    
    for (i = 0; i < MAX_KEYS; i++)
    {
        mKeyStates[i] = 0;
    }
}

- (uint32_t) getState: (int) key;
{
    if (!mEnabled)
        return 0;
    return mKeyStates[key];
}

@end

@implementation MameKeyboard (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;
{
    mKeyStates[usageId] = 1;
}

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;
{
    mKeyStates[usageId] = 0;
}

@end
