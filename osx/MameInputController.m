//
//  MameInputController.m
//  mameosx
//
//  Created by Dave Dribin on 9/4/06.
//

#import "MameInputController.h"

// MAME headers
#include "driver.h"


@implementation MameInputController

/*
 * The key states from 0 to 255 are for normal, ASCII keys.
 * The key states from 256 to 511 are for function keys.
 * The key states above 511 are for modifier keys.
 */

#define FUNC_TO_INDEX(_func_unichar_) (_func_unichar_ - 0xF700 + 256)

enum
{
    MAME_OSX_CONTROL = 512,
    MAME_OSX_OPTION,
    MAME_OSX_COMMAND,

    MAME_OSX_NUM_KEYSTATES
};

static os_code_info codelist[] = {
    {"ESC",     '\e',   KEYCODE_ESC},
    {"Tab",     '\t',   KEYCODE_TAB},
    {"1",       '1',    KEYCODE_1},
    {"2",       '2',    KEYCODE_2},
    {"3",       '3',    KEYCODE_3},
    {"4",       '4',    KEYCODE_4},
    {"5",       '5',    KEYCODE_5},
    {"P",       'P',    KEYCODE_P},
    {"Space",   ' ',    KEYCODE_SPACE},
    
    {"Up",      FUNC_TO_INDEX(NSUpArrowFunctionKey),    KEYCODE_UP},
    {"Down",    FUNC_TO_INDEX(NSDownArrowFunctionKey),  KEYCODE_DOWN},
    {"Left",    FUNC_TO_INDEX(NSLeftArrowFunctionKey),  KEYCODE_LEFT},
    {"Right",   FUNC_TO_INDEX(NSRightArrowFunctionKey), KEYCODE_RIGHT},

    {"F1",      FUNC_TO_INDEX(NSF1FunctionKey),         KEYCODE_F1},
    {"F2",      FUNC_TO_INDEX(NSF2FunctionKey),         KEYCODE_F2},
    {"F3",      FUNC_TO_INDEX(NSF3FunctionKey),         KEYCODE_F3},
    {"F4",      FUNC_TO_INDEX(NSF4FunctionKey),         KEYCODE_F4},
    {"F5",      FUNC_TO_INDEX(NSF5FunctionKey),         KEYCODE_F5},
    
    {"Control", MAME_OSX_CONTROL,     KEYCODE_LCONTROL},
    {"Option",  MAME_OSX_OPTION,      KEYCODE_LALT},
    {"Command", MAME_OSX_COMMAND,     KEYCODE_LWIN},
    
    {0,         0,      0}
};

- (id) init
{
    if (![super init])
        return;
    
    mKeyStates = malloc(MAME_OSX_NUM_KEYSTATES * sizeof(INT32));
    
    return self;
}

- (void) dealloc
{
    free(mKeyStates);
    [super dealloc];
}


- (void) osd_init;
{
    int i;
    for (i = 0; i < MAME_OSX_NUM_KEYSTATES; i++)
    {
        mKeyStates[i] = 0;
    }
}

- (const os_code_info *) osd_get_code_list;
{
    return codelist;
}

- (INT32) osd_get_code_value: (os_code) code;
{
    return mKeyStates[code];
}

- (void) handleKeyDown: (NSEvent *) event;
{
    NSString * characters = [event charactersIgnoringModifiers];
    unichar firstChar = [characters characterAtIndex: 0];
    if (firstChar < 256)
    {
        mKeyStates[firstChar] = 1;
    }
    else if ((firstChar >= 0xF700) && (firstChar <= 0xF7FF))
    {
        mKeyStates[FUNC_TO_INDEX(firstChar)] = 1;
    }
}

- (void) handleKeyUp: (NSEvent *) event;
{
    NSString * characters = [event charactersIgnoringModifiers];
    unichar firstChar = [characters characterAtIndex: 0];
    if (firstChar < 256)
    {
        int index = firstChar;
        mKeyStates[index] = 0;
    }
    else if ((firstChar >= 0xF700) && (firstChar <= 0xF7FF))
    {
        mKeyStates[FUNC_TO_INDEX(firstChar)] = 0;
    }
}

- (void) flagsChanged: (NSEvent *) event;
{
    unsigned int flags = [event modifierFlags];
    mKeyStates[MAME_OSX_CONTROL] = (flags & NSControlKeyMask) ? 1 : 0;
    mKeyStates[MAME_OSX_OPTION] = (flags & NSAlternateKeyMask) ? 1 : 0;
    mKeyStates[MAME_OSX_COMMAND] = (flags & NSCommandKeyMask) ? 1 : 0;
}

@end
