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

#define FIRST_FUNCTION_KEY 0xF700
#define LAST_FUNCTION_KEY 0xF7FF
#define FUNCTION_KEY_INDEX_BASE 256

static inline BOOL isAscii(unichar code)
{
    if (code < 256)
        return YES;
    else
        return NO;
}

static inline BOOL isFunctionKey(unichar code)
{
    if ((code >= FIRST_FUNCTION_KEY) && (code <= LAST_FUNCTION_KEY))
        return YES;
    else
        return NO;
}

// This needs to be a macro so it can be used in the codelist initializer
#define FUNC_TO_INDEX(_func_unichar_) (_func_unichar_ - FIRST_FUNCTION_KEY + 256)

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
    {"6",       '6',    KEYCODE_6},
    {"7",       '7',    KEYCODE_7},
    {"8",       '8',    KEYCODE_8},
    {"9",       '9',    KEYCODE_9},
	
    {"A",       'a',    KEYCODE_A},
    {"B",       'b',    KEYCODE_B},
    {"C",       'c',    KEYCODE_C},
    {"D",       'd',    KEYCODE_D},
    {"E",       'e',    KEYCODE_E},
    {"F",       'f',    KEYCODE_F},
    {"G",       'g',    KEYCODE_G},
    {"H",       'h',    KEYCODE_H},
    {"I",       'i',    KEYCODE_I},
    {"J",       'j',    KEYCODE_J},
    {"K",       'k',    KEYCODE_K},
    {"L",       'l',    KEYCODE_L},
    {"M",       'm',    KEYCODE_M},
    {"N",       'n',    KEYCODE_N},
    {"O",       'o',    KEYCODE_O},
    {"P",       'p',    KEYCODE_P},
    {"Q",       'q',    KEYCODE_Q},
    {"R",       'r',    KEYCODE_R},
    {"S",       's',    KEYCODE_S},
    {"T",       't',    KEYCODE_T},
    {"U",       'u',    KEYCODE_U},
    {"V",       'v',    KEYCODE_V},
    {"W",       'w',    KEYCODE_W},
    {"X",       'x',    KEYCODE_X},
    {"Y",       'y',    KEYCODE_Y},
    {"Z",       'z',    KEYCODE_Z},
	
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
    {"F6",		FUNC_TO_INDEX(NSF6FunctionKey),			KEYCODE_F6},
    {"F7",		FUNC_TO_INDEX(NSF7FunctionKey),			KEYCODE_F7},
    {"F8",		FUNC_TO_INDEX(NSF8FunctionKey),			KEYCODE_F8},
    {"F9",		FUNC_TO_INDEX(NSF9FunctionKey),			KEYCODE_F9},
    {"F10",		FUNC_TO_INDEX(NSF10FunctionKey),		KEYCODE_F10},
    {"F11",		FUNC_TO_INDEX(NSF11FunctionKey),		KEYCODE_F11},
    {"F12",		FUNC_TO_INDEX(NSF12FunctionKey),		KEYCODE_F12},
    {"F13",		FUNC_TO_INDEX(NSF13FunctionKey),		KEYCODE_F13},
    {"F14",		FUNC_TO_INDEX(NSF14FunctionKey),		KEYCODE_F14},
    {"F15",		FUNC_TO_INDEX(NSF15FunctionKey),		KEYCODE_F15},
	
    
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
    if (isAscii(firstChar))
    {
        mKeyStates[firstChar] = 1;
    }
    else if (isFunctionKey(firstChar))
    {
        mKeyStates[FUNC_TO_INDEX(firstChar)] = 1;
    }
}

- (void) handleKeyUp: (NSEvent *) event;
{
    NSString * characters = [event charactersIgnoringModifiers];
    unichar firstChar = [characters characterAtIndex: 0];
    if (isAscii(firstChar))
    {
        mKeyStates[firstChar] = 0;
    }
    else if (isFunctionKey(firstChar))
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
