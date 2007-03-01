/*
 * Copyright (c) 2006 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "MameInputController.h"
#import "DDHidLib.h"

// MAME headers
#include "driver.h"

#define MAX_KEYS 256
#define MAX_JOY 256

// macros for building/mapping joystick codes
#define JOYCODE(joy, type, index)	((index) | ((type) << 8) | ((joy) << 12) | 0x80000000)
#define JOYINDEX(joycode)			((joycode) & 0xff)
#define CODETYPE(joycode)			(((joycode) >> 8) & 0xf)
#define JOYNUM(joycode)				(((joycode) >> 12) & 0xf)

// macros for differentiating the two
#define IS_KEYBOARD_CODE(code)		(((code) & 0x80000000) == 0)
#define IS_JOYSTICK_CODE(code)		(((code) & 0x80000000) != 0)

// joystick types
#define CODETYPE_KEYBOARD			0
#define CODETYPE_AXIS_NEG			1
#define CODETYPE_AXIS_POS			2
#define CODETYPE_POV_UP				3
#define CODETYPE_POV_DOWN			4
#define CODETYPE_POV_LEFT			5
#define CODETYPE_POV_RIGHT			6
#define CODETYPE_BUTTON				7
#define CODETYPE_JOYAXIS			8
#define CODETYPE_MOUSEAXIS			9
#define CODETYPE_MOUSEBUTTON		10
#define CODETYPE_GUNAXIS			11

#define ELEMENTS(x)			(sizeof(x) / sizeof((x)[0]))

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
    MAME_OSX_SHIFT,

    MAME_OSX_NUM_KEYSTATES
};

static os_code_info codelist[] = {
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
	
    {"ESC",     '\e',   KEYCODE_ESC},
    {"~",       '~',    KEYCODE_TILDE},
    {"-",       '-',    KEYCODE_MINUS},
    {"=",       '=',    KEYCODE_EQUALS},
    // KEYCODE_BACKSPACE
    {"Tab",     '\t',   KEYCODE_TAB},
    {"{",       '{',    KEYCODE_OPENBRACE},
    {"}",       '}',    KEYCODE_CLOSEBRACE},
    {"Return",  '\r',   KEYCODE_ENTER},
    {":",       ':',    KEYCODE_COLON},
    {"'",       '\'',   KEYCODE_QUOTE},
    {"\\",      '\\',   KEYCODE_BACKSLASH},
    // KEYCODE_BACKSLASH2
    {",",       ',',    KEYCODE_COMMA},
    // KEYCODE_STOP
    {"/",       '/',    KEYCODE_SLASH},
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
	
    
    {"Control", MAME_OSX_CONTROL,   KEYCODE_LCONTROL},
    {"Option",  MAME_OSX_OPTION,    KEYCODE_LALT},
    {"Command", MAME_OSX_COMMAND,   KEYCODE_LWIN},
    {"Shift",   MAME_OSX_SHIFT,     KEYCODE_LSHIFT},
    
    {0,         0,      0}
};

// master joystick translation table
static int joy_trans_table[][2] =
{
	// internal code                    MAME code
	{ JOYCODE(0, CODETYPE_AXIS_NEG, 0),	JOYCODE_1_LEFT },
	{ JOYCODE(0, CODETYPE_AXIS_POS, 0),	JOYCODE_1_RIGHT },
	{ JOYCODE(0, CODETYPE_AXIS_NEG, 1),	JOYCODE_1_UP },
	{ JOYCODE(0, CODETYPE_AXIS_POS, 1),	JOYCODE_1_DOWN },
	{ JOYCODE(0, CODETYPE_BUTTON, 0),	JOYCODE_1_BUTTON1 },
	{ JOYCODE(0, CODETYPE_BUTTON, 1),	JOYCODE_1_BUTTON2 },
	{ JOYCODE(0, CODETYPE_BUTTON, 2),	JOYCODE_1_BUTTON3 },
	{ JOYCODE(0, CODETYPE_BUTTON, 3),	JOYCODE_1_BUTTON4 },
	{ JOYCODE(0, CODETYPE_BUTTON, 4),	JOYCODE_1_BUTTON5 },
	{ JOYCODE(0, CODETYPE_BUTTON, 5),	JOYCODE_1_BUTTON6 },
	{ JOYCODE(0, CODETYPE_BUTTON, 6),	JOYCODE_1_BUTTON7 },
	{ JOYCODE(0, CODETYPE_BUTTON, 7),	JOYCODE_1_BUTTON8 },
	{ JOYCODE(0, CODETYPE_BUTTON, 8),	JOYCODE_1_BUTTON9 },
	{ JOYCODE(0, CODETYPE_BUTTON, 9),	JOYCODE_1_BUTTON10 },
	{ JOYCODE(0, CODETYPE_BUTTON, 10),	JOYCODE_1_BUTTON11 },
	{ JOYCODE(0, CODETYPE_BUTTON, 11),	JOYCODE_1_BUTTON12 },
	{ JOYCODE(0, CODETYPE_BUTTON, 12),	JOYCODE_1_BUTTON13 },
	{ JOYCODE(0, CODETYPE_BUTTON, 13),	JOYCODE_1_BUTTON14 },
	{ JOYCODE(0, CODETYPE_BUTTON, 14),	JOYCODE_1_BUTTON15 },
	{ JOYCODE(0, CODETYPE_BUTTON, 15),	JOYCODE_1_BUTTON16 },
	{ JOYCODE(0, CODETYPE_JOYAXIS, 0),	JOYCODE_1_ANALOG_X },
	{ JOYCODE(0, CODETYPE_JOYAXIS, 1),	JOYCODE_1_ANALOG_Y },
	{ JOYCODE(0, CODETYPE_JOYAXIS, 2),	JOYCODE_1_ANALOG_Z },
    
	{ JOYCODE(1, CODETYPE_AXIS_NEG, 0),	JOYCODE_2_LEFT },
	{ JOYCODE(1, CODETYPE_AXIS_POS, 0),	JOYCODE_2_RIGHT },
	{ JOYCODE(1, CODETYPE_AXIS_NEG, 1),	JOYCODE_2_UP },
	{ JOYCODE(1, CODETYPE_AXIS_POS, 1),	JOYCODE_2_DOWN },
	{ JOYCODE(1, CODETYPE_BUTTON, 0),	JOYCODE_2_BUTTON1 },
	{ JOYCODE(1, CODETYPE_BUTTON, 1),	JOYCODE_2_BUTTON2 },
	{ JOYCODE(1, CODETYPE_BUTTON, 2),	JOYCODE_2_BUTTON3 },
	{ JOYCODE(1, CODETYPE_BUTTON, 3),	JOYCODE_2_BUTTON4 },
	{ JOYCODE(1, CODETYPE_BUTTON, 4),	JOYCODE_2_BUTTON5 },
	{ JOYCODE(1, CODETYPE_BUTTON, 5),	JOYCODE_2_BUTTON6 },
	{ JOYCODE(1, CODETYPE_BUTTON, 6),	JOYCODE_2_BUTTON7 },
	{ JOYCODE(1, CODETYPE_BUTTON, 7),	JOYCODE_2_BUTTON8 },
	{ JOYCODE(1, CODETYPE_BUTTON, 8),	JOYCODE_2_BUTTON9 },
	{ JOYCODE(1, CODETYPE_BUTTON, 9),	JOYCODE_2_BUTTON10 },
	{ JOYCODE(1, CODETYPE_BUTTON, 10),	JOYCODE_2_BUTTON11 },
	{ JOYCODE(1, CODETYPE_BUTTON, 11),	JOYCODE_2_BUTTON12 },
	{ JOYCODE(1, CODETYPE_BUTTON, 12),	JOYCODE_2_BUTTON13 },
	{ JOYCODE(1, CODETYPE_BUTTON, 13),	JOYCODE_2_BUTTON14 },
	{ JOYCODE(1, CODETYPE_BUTTON, 14),	JOYCODE_2_BUTTON15 },
	{ JOYCODE(1, CODETYPE_BUTTON, 15),	JOYCODE_2_BUTTON16 },
	{ JOYCODE(1, CODETYPE_JOYAXIS, 0),	JOYCODE_2_ANALOG_X },
	{ JOYCODE(1, CODETYPE_JOYAXIS, 1),	JOYCODE_2_ANALOG_Y },
	{ JOYCODE(1, CODETYPE_JOYAXIS, 2),	JOYCODE_2_ANALOG_Z },
    
	{ JOYCODE(2, CODETYPE_AXIS_NEG, 0),	JOYCODE_3_LEFT },
	{ JOYCODE(2, CODETYPE_AXIS_POS, 0),	JOYCODE_3_RIGHT },
	{ JOYCODE(2, CODETYPE_AXIS_NEG, 1),	JOYCODE_3_UP },
	{ JOYCODE(2, CODETYPE_AXIS_POS, 1),	JOYCODE_3_DOWN },
	{ JOYCODE(2, CODETYPE_BUTTON, 0),	JOYCODE_3_BUTTON1 },
	{ JOYCODE(2, CODETYPE_BUTTON, 1),	JOYCODE_3_BUTTON2 },
	{ JOYCODE(2, CODETYPE_BUTTON, 2),	JOYCODE_3_BUTTON3 },
	{ JOYCODE(2, CODETYPE_BUTTON, 3),	JOYCODE_3_BUTTON4 },
	{ JOYCODE(2, CODETYPE_BUTTON, 4),	JOYCODE_3_BUTTON5 },
	{ JOYCODE(2, CODETYPE_BUTTON, 5),	JOYCODE_3_BUTTON6 },
	{ JOYCODE(2, CODETYPE_BUTTON, 6),	JOYCODE_3_BUTTON7 },
	{ JOYCODE(2, CODETYPE_BUTTON, 7),	JOYCODE_3_BUTTON8 },
	{ JOYCODE(2, CODETYPE_BUTTON, 8),	JOYCODE_3_BUTTON9 },
	{ JOYCODE(2, CODETYPE_BUTTON, 9),	JOYCODE_3_BUTTON10 },
	{ JOYCODE(2, CODETYPE_BUTTON, 10),	JOYCODE_3_BUTTON11 },
	{ JOYCODE(2, CODETYPE_BUTTON, 11),	JOYCODE_3_BUTTON12 },
	{ JOYCODE(2, CODETYPE_BUTTON, 12),	JOYCODE_3_BUTTON13 },
	{ JOYCODE(2, CODETYPE_BUTTON, 13),	JOYCODE_3_BUTTON14 },
	{ JOYCODE(2, CODETYPE_BUTTON, 14),	JOYCODE_3_BUTTON15 },
	{ JOYCODE(2, CODETYPE_BUTTON, 15),	JOYCODE_3_BUTTON16 },
	{ JOYCODE(2, CODETYPE_JOYAXIS, 0),	JOYCODE_3_ANALOG_X },
	{ JOYCODE(2, CODETYPE_JOYAXIS, 1),	JOYCODE_3_ANALOG_Y },
	{ JOYCODE(2, CODETYPE_JOYAXIS, 2),	JOYCODE_3_ANALOG_Z },
    
	{ JOYCODE(3, CODETYPE_AXIS_NEG, 0),	JOYCODE_4_LEFT },
	{ JOYCODE(3, CODETYPE_AXIS_POS, 0),	JOYCODE_4_RIGHT },
	{ JOYCODE(3, CODETYPE_AXIS_NEG, 1),	JOYCODE_4_UP },
	{ JOYCODE(3, CODETYPE_AXIS_POS, 1),	JOYCODE_4_DOWN },
	{ JOYCODE(3, CODETYPE_BUTTON, 0),	JOYCODE_4_BUTTON1 },
	{ JOYCODE(3, CODETYPE_BUTTON, 1),	JOYCODE_4_BUTTON2 },
	{ JOYCODE(3, CODETYPE_BUTTON, 2),	JOYCODE_4_BUTTON3 },
	{ JOYCODE(3, CODETYPE_BUTTON, 3),	JOYCODE_4_BUTTON4 },
	{ JOYCODE(3, CODETYPE_BUTTON, 4),	JOYCODE_4_BUTTON5 },
	{ JOYCODE(3, CODETYPE_BUTTON, 5),	JOYCODE_4_BUTTON6 },
	{ JOYCODE(3, CODETYPE_BUTTON, 6),	JOYCODE_4_BUTTON7 },
	{ JOYCODE(3, CODETYPE_BUTTON, 7),	JOYCODE_4_BUTTON8 },
	{ JOYCODE(3, CODETYPE_BUTTON, 8),	JOYCODE_4_BUTTON9 },
	{ JOYCODE(3, CODETYPE_BUTTON, 9),	JOYCODE_4_BUTTON10 },
	{ JOYCODE(3, CODETYPE_BUTTON, 10),	JOYCODE_4_BUTTON11 },
	{ JOYCODE(3, CODETYPE_BUTTON, 11),	JOYCODE_4_BUTTON12 },
	{ JOYCODE(3, CODETYPE_BUTTON, 12),	JOYCODE_4_BUTTON13 },
	{ JOYCODE(3, CODETYPE_BUTTON, 13),	JOYCODE_4_BUTTON14 },
	{ JOYCODE(3, CODETYPE_BUTTON, 14),	JOYCODE_4_BUTTON15 },
	{ JOYCODE(3, CODETYPE_BUTTON, 15),	JOYCODE_4_BUTTON16 },
	{ JOYCODE(3, CODETYPE_JOYAXIS, 0),	JOYCODE_4_ANALOG_X },
	{ JOYCODE(3, CODETYPE_JOYAXIS, 1),	JOYCODE_4_ANALOG_Y },
	{ JOYCODE(3, CODETYPE_JOYAXIS, 2),	JOYCODE_4_ANALOG_Z },
    
	{ JOYCODE(4, CODETYPE_AXIS_NEG, 0),	JOYCODE_5_LEFT },
	{ JOYCODE(4, CODETYPE_AXIS_POS, 0),	JOYCODE_5_RIGHT },
	{ JOYCODE(4, CODETYPE_AXIS_NEG, 1),	JOYCODE_5_UP },
	{ JOYCODE(4, CODETYPE_AXIS_POS, 1),	JOYCODE_5_DOWN },
	{ JOYCODE(4, CODETYPE_BUTTON, 0),	JOYCODE_5_BUTTON1 },
	{ JOYCODE(4, CODETYPE_BUTTON, 1),	JOYCODE_5_BUTTON2 },
	{ JOYCODE(4, CODETYPE_BUTTON, 2),	JOYCODE_5_BUTTON3 },
	{ JOYCODE(4, CODETYPE_BUTTON, 3),	JOYCODE_5_BUTTON4 },
	{ JOYCODE(4, CODETYPE_BUTTON, 4),	JOYCODE_5_BUTTON5 },
	{ JOYCODE(4, CODETYPE_BUTTON, 5),	JOYCODE_5_BUTTON6 },
	{ JOYCODE(4, CODETYPE_BUTTON, 6),	JOYCODE_5_BUTTON7 },
	{ JOYCODE(4, CODETYPE_BUTTON, 7),	JOYCODE_5_BUTTON8 },
	{ JOYCODE(4, CODETYPE_BUTTON, 8),	JOYCODE_5_BUTTON9 },
	{ JOYCODE(4, CODETYPE_BUTTON, 9),	JOYCODE_5_BUTTON10 },
	{ JOYCODE(4, CODETYPE_BUTTON, 10),	JOYCODE_5_BUTTON11 },
	{ JOYCODE(4, CODETYPE_BUTTON, 11),	JOYCODE_5_BUTTON12 },
	{ JOYCODE(4, CODETYPE_BUTTON, 12),	JOYCODE_5_BUTTON13 },
	{ JOYCODE(4, CODETYPE_BUTTON, 13),	JOYCODE_5_BUTTON14 },
	{ JOYCODE(4, CODETYPE_BUTTON, 14),	JOYCODE_5_BUTTON15 },
	{ JOYCODE(4, CODETYPE_BUTTON, 15),	JOYCODE_5_BUTTON16 },
	{ JOYCODE(4, CODETYPE_JOYAXIS, 0),	JOYCODE_5_ANALOG_X },
	{ JOYCODE(4, CODETYPE_JOYAXIS, 1), 	JOYCODE_5_ANALOG_Y },
	{ JOYCODE(4, CODETYPE_JOYAXIS, 2),	JOYCODE_5_ANALOG_Z },
    
	{ JOYCODE(5, CODETYPE_AXIS_NEG, 0),	JOYCODE_6_LEFT },
	{ JOYCODE(5, CODETYPE_AXIS_POS, 0),	JOYCODE_6_RIGHT },
	{ JOYCODE(5, CODETYPE_AXIS_NEG, 1),	JOYCODE_6_UP },
	{ JOYCODE(5, CODETYPE_AXIS_POS, 1),	JOYCODE_6_DOWN },
	{ JOYCODE(5, CODETYPE_BUTTON, 0),	JOYCODE_6_BUTTON1 },
	{ JOYCODE(5, CODETYPE_BUTTON, 1),	JOYCODE_6_BUTTON2 },
	{ JOYCODE(5, CODETYPE_BUTTON, 2),	JOYCODE_6_BUTTON3 },
	{ JOYCODE(5, CODETYPE_BUTTON, 3),	JOYCODE_6_BUTTON4 },
	{ JOYCODE(5, CODETYPE_BUTTON, 4),	JOYCODE_6_BUTTON5 },
	{ JOYCODE(5, CODETYPE_BUTTON, 5),	JOYCODE_6_BUTTON6 },
	{ JOYCODE(5, CODETYPE_BUTTON, 6),	JOYCODE_6_BUTTON7 },
	{ JOYCODE(5, CODETYPE_BUTTON, 7),	JOYCODE_6_BUTTON8 },
	{ JOYCODE(5, CODETYPE_BUTTON, 8),	JOYCODE_6_BUTTON9 },
	{ JOYCODE(5, CODETYPE_BUTTON, 9),	JOYCODE_6_BUTTON10 },
	{ JOYCODE(5, CODETYPE_BUTTON, 10),	JOYCODE_6_BUTTON11 },
	{ JOYCODE(5, CODETYPE_BUTTON, 11),	JOYCODE_6_BUTTON12 },
	{ JOYCODE(5, CODETYPE_BUTTON, 12),	JOYCODE_6_BUTTON13 },
	{ JOYCODE(5, CODETYPE_BUTTON, 13),	JOYCODE_6_BUTTON14 },
	{ JOYCODE(5, CODETYPE_BUTTON, 14),	JOYCODE_6_BUTTON15 },
	{ JOYCODE(5, CODETYPE_BUTTON, 15),	JOYCODE_6_BUTTON16 },
	{ JOYCODE(5, CODETYPE_JOYAXIS, 0),	JOYCODE_6_ANALOG_X },
	{ JOYCODE(5, CODETYPE_JOYAXIS, 1),	JOYCODE_6_ANALOG_Y },
	{ JOYCODE(5, CODETYPE_JOYAXIS, 2),	JOYCODE_6_ANALOG_Z },
    
	{ JOYCODE(6, CODETYPE_AXIS_NEG, 0),	JOYCODE_7_LEFT },
	{ JOYCODE(6, CODETYPE_AXIS_POS, 0),	JOYCODE_7_RIGHT },
	{ JOYCODE(6, CODETYPE_AXIS_NEG, 1),	JOYCODE_7_UP },
	{ JOYCODE(6, CODETYPE_AXIS_POS, 1),	JOYCODE_7_DOWN },
	{ JOYCODE(6, CODETYPE_BUTTON, 0),	JOYCODE_7_BUTTON1 },
	{ JOYCODE(6, CODETYPE_BUTTON, 1),	JOYCODE_7_BUTTON2 },
	{ JOYCODE(6, CODETYPE_BUTTON, 2),	JOYCODE_7_BUTTON3 },
	{ JOYCODE(6, CODETYPE_BUTTON, 3),	JOYCODE_7_BUTTON4 },
	{ JOYCODE(6, CODETYPE_BUTTON, 4),	JOYCODE_7_BUTTON5 },
	{ JOYCODE(6, CODETYPE_BUTTON, 5),	JOYCODE_7_BUTTON6 },
	{ JOYCODE(6, CODETYPE_BUTTON, 6),	JOYCODE_7_BUTTON7 },
	{ JOYCODE(6, CODETYPE_BUTTON, 7),	JOYCODE_7_BUTTON8 },
	{ JOYCODE(6, CODETYPE_BUTTON, 8),	JOYCODE_7_BUTTON9 },
	{ JOYCODE(6, CODETYPE_BUTTON, 9),	JOYCODE_7_BUTTON10 },
	{ JOYCODE(6, CODETYPE_BUTTON, 10),	JOYCODE_7_BUTTON11 },
	{ JOYCODE(6, CODETYPE_BUTTON, 11),	JOYCODE_7_BUTTON12 },
	{ JOYCODE(6, CODETYPE_BUTTON, 12),	JOYCODE_7_BUTTON13 },
	{ JOYCODE(6, CODETYPE_BUTTON, 13),	JOYCODE_7_BUTTON14 },
	{ JOYCODE(6, CODETYPE_BUTTON, 14),	JOYCODE_7_BUTTON15 },
	{ JOYCODE(6, CODETYPE_BUTTON, 15),	JOYCODE_7_BUTTON16 },
	{ JOYCODE(6, CODETYPE_JOYAXIS, 0),	JOYCODE_7_ANALOG_X },
	{ JOYCODE(6, CODETYPE_JOYAXIS, 1),	JOYCODE_7_ANALOG_Y },
	{ JOYCODE(6, CODETYPE_JOYAXIS, 2),	JOYCODE_7_ANALOG_Z },
    
	{ JOYCODE(7, CODETYPE_AXIS_NEG, 0),	JOYCODE_8_LEFT },
	{ JOYCODE(7, CODETYPE_AXIS_POS, 0),	JOYCODE_8_RIGHT },
	{ JOYCODE(7, CODETYPE_AXIS_NEG, 1),	JOYCODE_8_UP },
	{ JOYCODE(7, CODETYPE_AXIS_POS, 1),	JOYCODE_8_DOWN },
	{ JOYCODE(7, CODETYPE_BUTTON, 0),	JOYCODE_8_BUTTON1 },
	{ JOYCODE(7, CODETYPE_BUTTON, 1),	JOYCODE_8_BUTTON2 },
	{ JOYCODE(7, CODETYPE_BUTTON, 2),	JOYCODE_8_BUTTON3 },
	{ JOYCODE(7, CODETYPE_BUTTON, 3),	JOYCODE_8_BUTTON4 },
	{ JOYCODE(7, CODETYPE_BUTTON, 4),	JOYCODE_8_BUTTON5 },
	{ JOYCODE(7, CODETYPE_BUTTON, 5),	JOYCODE_8_BUTTON6 },
	{ JOYCODE(7, CODETYPE_BUTTON, 6),	JOYCODE_8_BUTTON7 },
	{ JOYCODE(7, CODETYPE_BUTTON, 7),	JOYCODE_8_BUTTON8 },
	{ JOYCODE(7, CODETYPE_BUTTON, 8),	JOYCODE_8_BUTTON9 },
	{ JOYCODE(7, CODETYPE_BUTTON, 9),	JOYCODE_8_BUTTON10 },
	{ JOYCODE(7, CODETYPE_BUTTON, 10),	JOYCODE_8_BUTTON11 },
	{ JOYCODE(7, CODETYPE_BUTTON, 11),	JOYCODE_8_BUTTON12 },
	{ JOYCODE(7, CODETYPE_BUTTON, 12),	JOYCODE_8_BUTTON13 },
	{ JOYCODE(7, CODETYPE_BUTTON, 13),	JOYCODE_8_BUTTON14 },
	{ JOYCODE(7, CODETYPE_BUTTON, 14),	JOYCODE_8_BUTTON15 },
	{ JOYCODE(7, CODETYPE_BUTTON, 15),	JOYCODE_8_BUTTON16 },
	{ JOYCODE(7, CODETYPE_JOYAXIS, 0),	JOYCODE_8_ANALOG_X },
	{ JOYCODE(7, CODETYPE_JOYAXIS, 1),	JOYCODE_8_ANALOG_Y },
	{ JOYCODE(7, CODETYPE_JOYAXIS, 2),	JOYCODE_8_ANALOG_Z },
    
	{ JOYCODE(0, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_1_BUTTON1 },
	{ JOYCODE(0, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_1_BUTTON2 },
	{ JOYCODE(0, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_1_BUTTON3 },
	{ JOYCODE(0, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_1_BUTTON4 },
	{ JOYCODE(0, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_1_BUTTON5 },
	{ JOYCODE(0, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_1_ANALOG_X },
	{ JOYCODE(0, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_1_ANALOG_Y },
	{ JOYCODE(0, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_1_ANALOG_Z },
    
	{ JOYCODE(1, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_2_BUTTON1 },
	{ JOYCODE(1, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_2_BUTTON2 },
	{ JOYCODE(1, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_2_BUTTON3 },
	{ JOYCODE(1, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_2_BUTTON4 },
	{ JOYCODE(1, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_2_BUTTON5 },
	{ JOYCODE(1, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_2_ANALOG_X },
	{ JOYCODE(1, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_2_ANALOG_Y },
	{ JOYCODE(1, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_2_ANALOG_Z },
    
	{ JOYCODE(2, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_3_BUTTON1 },
	{ JOYCODE(2, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_3_BUTTON2 },
	{ JOYCODE(2, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_3_BUTTON3 },
	{ JOYCODE(2, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_3_BUTTON4 },
	{ JOYCODE(2, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_3_BUTTON5 },
	{ JOYCODE(2, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_3_ANALOG_X },
	{ JOYCODE(2, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_3_ANALOG_Y },
	{ JOYCODE(2, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_3_ANALOG_Z },
    
	{ JOYCODE(3, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_4_BUTTON1 },
	{ JOYCODE(3, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_4_BUTTON2 },
	{ JOYCODE(3, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_4_BUTTON3 },
	{ JOYCODE(3, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_4_BUTTON4 },
	{ JOYCODE(3, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_4_BUTTON5 },
	{ JOYCODE(3, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_4_ANALOG_X },
	{ JOYCODE(3, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_4_ANALOG_Y },
	{ JOYCODE(3, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_4_ANALOG_Z },
    
	{ JOYCODE(4, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_5_BUTTON1 },
	{ JOYCODE(4, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_5_BUTTON2 },
	{ JOYCODE(4, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_5_BUTTON3 },
	{ JOYCODE(4, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_5_BUTTON4 },
	{ JOYCODE(4, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_5_BUTTON5 },
	{ JOYCODE(4, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_5_ANALOG_X },
	{ JOYCODE(4, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_5_ANALOG_Y },
	{ JOYCODE(4, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_5_ANALOG_Z },
    
	{ JOYCODE(5, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_6_BUTTON1 },
	{ JOYCODE(5, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_6_BUTTON2 },
	{ JOYCODE(5, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_6_BUTTON3 },
	{ JOYCODE(5, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_6_BUTTON4 },
	{ JOYCODE(5, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_6_BUTTON5 },
	{ JOYCODE(5, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_6_ANALOG_X },
	{ JOYCODE(5, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_6_ANALOG_Y },
	{ JOYCODE(5, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_6_ANALOG_Z },
    
	{ JOYCODE(6, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_7_BUTTON1 },
	{ JOYCODE(6, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_7_BUTTON2 },
	{ JOYCODE(6, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_7_BUTTON3 },
	{ JOYCODE(6, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_7_BUTTON4 },
	{ JOYCODE(6, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_7_BUTTON5 },
	{ JOYCODE(6, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_7_ANALOG_X },
	{ JOYCODE(6, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_7_ANALOG_Y },
	{ JOYCODE(6, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_7_ANALOG_Z },
    
	{ JOYCODE(7, CODETYPE_MOUSEBUTTON, 0), 	MOUSECODE_8_BUTTON1 },
	{ JOYCODE(7, CODETYPE_MOUSEBUTTON, 1), 	MOUSECODE_8_BUTTON2 },
	{ JOYCODE(7, CODETYPE_MOUSEBUTTON, 2), 	MOUSECODE_8_BUTTON3 },
	{ JOYCODE(7, CODETYPE_MOUSEBUTTON, 3), 	MOUSECODE_8_BUTTON4 },
	{ JOYCODE(7, CODETYPE_MOUSEBUTTON, 4), 	MOUSECODE_8_BUTTON5 },
	{ JOYCODE(7, CODETYPE_MOUSEAXIS, 0),	MOUSECODE_8_ANALOG_X },
	{ JOYCODE(7, CODETYPE_MOUSEAXIS, 1),	MOUSECODE_8_ANALOG_Y },
	{ JOYCODE(7, CODETYPE_MOUSEAXIS, 2),	MOUSECODE_8_ANALOG_Z },
    
	{ JOYCODE(0, CODETYPE_GUNAXIS, 0),		GUNCODE_1_ANALOG_X },
	{ JOYCODE(0, CODETYPE_GUNAXIS, 1),		GUNCODE_1_ANALOG_Y },
    
	{ JOYCODE(1, CODETYPE_GUNAXIS, 0),		GUNCODE_2_ANALOG_X },
	{ JOYCODE(1, CODETYPE_GUNAXIS, 1),		GUNCODE_2_ANALOG_Y },
    
	{ JOYCODE(2, CODETYPE_GUNAXIS, 0),		GUNCODE_3_ANALOG_X },
	{ JOYCODE(2, CODETYPE_GUNAXIS, 1),		GUNCODE_3_ANALOG_Y },
    
	{ JOYCODE(3, CODETYPE_GUNAXIS, 0),		GUNCODE_4_ANALOG_X },
	{ JOYCODE(3, CODETYPE_GUNAXIS, 1),		GUNCODE_4_ANALOG_Y },
    
	{ JOYCODE(4, CODETYPE_GUNAXIS, 0),		GUNCODE_5_ANALOG_X },
	{ JOYCODE(4, CODETYPE_GUNAXIS, 1),		GUNCODE_5_ANALOG_Y },
    
	{ JOYCODE(5, CODETYPE_GUNAXIS, 0),		GUNCODE_6_ANALOG_X },
	{ JOYCODE(5, CODETYPE_GUNAXIS, 1),		GUNCODE_6_ANALOG_Y },
    
	{ JOYCODE(6, CODETYPE_GUNAXIS, 0),		GUNCODE_7_ANALOG_X },
	{ JOYCODE(6, CODETYPE_GUNAXIS, 1),		GUNCODE_7_ANALOG_Y },
    
	{ JOYCODE(7, CODETYPE_GUNAXIS, 0),		GUNCODE_8_ANALOG_X },
	{ JOYCODE(7, CODETYPE_GUNAXIS, 1),		GUNCODE_8_ANALOG_Y },
};

@interface MameInputControllerPrivate : NSObject
{
  @public
    os_code_info mCodelist[MAX_KEYS+MAX_JOY];
    int mTotalCodes;
    INT32 mKeyStates[MAME_OSX_NUM_KEYSTATES];
    NSMutableArray * mJoystickNames;
    NSMutableArray * mJoysticks;
}

- (id) init;

@end

@implementation MameInputControllerPrivate

- (id) init;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mJoystickNames = [[NSMutableArray alloc] init];
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mJoystickNames release];
    
    mJoystickNames = nil;
    [super dealloc];
}

@end


@interface MameInputController (Private)

- (void) initKeyCodes;

- (void) initJoyCodes;

@end

@interface MameInputController (DDHidJoystickDelegate)

- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            xChanged: (int) value;
- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            yChanged: (int) value;
- (void) hidJoystick: (DDHidJoystick *) joystick
          buttonDown: (unsigned) buttonNumber;
- (void) hidJoystick: (DDHidJoystick *) joystick
            buttonUp: (unsigned) buttonNumber;

@end

@implementation MameInputController

- (id) init
{
    if ([super init] == nil)
        return nil;
    
    p = [[MameInputControllerPrivate alloc] init];
    
    return self;
}

- (void) dealloc
{
    [p dealloc];
    [super dealloc];
}


- (void) osd_init;
{
    p->mTotalCodes = 0;

    [self initKeyCodes];
    [self initJoyCodes];

    // terminate array
	memset(&p->mCodelist[p->mTotalCodes], 0, sizeof(p->mCodelist[0]));

    
    int i;
    for (i = 0; i < MAME_OSX_NUM_KEYSTATES; i++)
    {
        p->mKeyStates[i] = 0;
    }
}

- (const os_code_info *) osd_get_code_list;
{
    return p->mCodelist;
}


#define MAX_KEYBOARDS		1
#define MAX_MICE			8
#define MAX_JOYSTICKS		8
#define MAX_LIGHTGUNS		2

#define MAX_JOY				256
#define MAX_AXES			8
#define MAX_BUTTONS			32
#define MAX_POV				4

static struct {
	int axes[MAX_AXES];
	int buttons[MAX_BUTTONS];
} joystick_state[MAX_JOYSTICKS];

static float a2d_deadzone = 0.3;

- (INT32) getJoyCodeValue: (os_code) joycode;
{
	int joyindex = JOYINDEX(joycode);
	int codetype = CODETYPE(joycode);
	int joynum = JOYNUM(joycode);
    INT32 value = 0;

	switch (codetype)
	{
		case CODETYPE_BUTTON:
			return joystick_state[joynum].buttons[joyindex];

		case CODETYPE_AXIS_POS:
		case CODETYPE_AXIS_NEG:
        {
			int val = joystick_state[joynum].axes[joyindex];
			int top = ANALOG_VALUE_MAX;
			int bottom = ANALOG_VALUE_MIN;
			int middle = 0;
            
			// watch for movement greater "a2d_deadzone" along either axis
			// FIXME in the two-axis joystick case, we need to find out
			// the angle. Anything else is unprecise.
			if (codetype == CODETYPE_AXIS_POS)
				return (val > middle + ((top - middle) * a2d_deadzone));
			else
				return (val < middle - ((middle - bottom) * a2d_deadzone));
        }

        // analog joystick axis
		case CODETYPE_JOYAXIS:
		{
			int val = ((int *)&joystick_state[joynum].axes)[joyindex];
            
            if (val < ANALOG_VALUE_MIN) val = ANALOG_VALUE_MIN;
			if (val > ANALOG_VALUE_MAX) val = ANALOG_VALUE_MAX;
			return val;
		}

    }

    return value;
}

- (INT32) osd_get_code_value: (os_code) code;
{
    INT32 value;
    @synchronized(self)
    {
        if (IS_KEYBOARD_CODE(code))
            value = p->mKeyStates[code];
        else
            return [self getJoyCodeValue: code];
    }
    return value;
}

- (void) keyDown: (NSEvent *) event;
{
    @synchronized(self)
    {
        NSString * characters = [event charactersIgnoringModifiers];
        unichar firstChar = [characters characterAtIndex: 0];
        if (isAscii(firstChar))
        {
            p->mKeyStates[firstChar] = 1;
        }
        else if (isFunctionKey(firstChar))
        {
            p->mKeyStates[FUNC_TO_INDEX(firstChar)] = 1;
        }
    }
}

- (void) keyUp: (NSEvent *) event;
{
    @synchronized(self)
    {
        NSString * characters = [event charactersIgnoringModifiers];
        unichar firstChar = [characters characterAtIndex: 0];
        if (isAscii(firstChar))
        {
            p->mKeyStates[firstChar] = 0;
        }
        else if (isFunctionKey(firstChar))
        {
            p->mKeyStates[FUNC_TO_INDEX(firstChar)] = 0;
        }
    }
}

- (void) flagsChanged: (NSEvent *) event;
{
    @synchronized(self)
    {
        unsigned int flags = [event modifierFlags];
        p->mKeyStates[MAME_OSX_CONTROL] = (flags & NSControlKeyMask) ? 1 : 0;
        p->mKeyStates[MAME_OSX_OPTION] = (flags & NSAlternateKeyMask) ? 1 : 0;
        p->mKeyStates[MAME_OSX_COMMAND] = (flags & NSCommandKeyMask) ? 1 : 0;
    }
}

@end

@implementation MameInputController (Private)

- (void) initKeyCodes;
{
    int i= 0;
    while (codelist[i].name != 0)
    {
        p->mCodelist[p->mTotalCodes] = codelist[i];
        p->mTotalCodes++;
        i++;
    }
}

static NSMutableData * utf8Data(NSString * string)
{
    NSMutableData * data = [NSMutableData dataWithData: [string dataUsingEncoding: NSUTF8StringEncoding]];
    char null = '\0';
    [data appendBytes: &null length: 1];
    return data;
}

- (void) add_joylist_entry: (NSString *) name
                      code: (os_code) code
                input_code: (input_code) standardcode;
{
    int entry;
    
#if 1
    NSMutableData * data = utf8Data(name);
    char * bytes = [data mutableBytes];
    [p->mJoystickNames addObject: data];
#else
    const char * bytes = [name cStringUsingEncoding: NSUTF8StringEncoding];
    [p->mJoystickNames addObject: name];
#endif

    // find the table entry, if there is one
    for (entry = 0; entry < ELEMENTS(joy_trans_table); entry++)
        if (joy_trans_table[entry][0] == code)
            break;
    
    // fill in the joy description
    p->mCodelist[p->mTotalCodes].name = bytes;
    p->mCodelist[p->mTotalCodes].oscode = code;
    if (entry < ELEMENTS(joy_trans_table))
        standardcode = joy_trans_table[entry][1];
    p->mCodelist[p->mTotalCodes].inputcode = standardcode;
    p->mTotalCodes++;
}

static NSString * format(NSString * format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString * string = [[NSString alloc] initWithFormat: format
                                               arguments: arguments];
    [string autorelease];
    va_end(arguments);
    return string;
}

- (void) initJoyCodes;
{
    [p->mJoystickNames removeAllObjects];
    p->mJoysticks = [[NSMutableArray alloc] init];
    NSArray * joysticks = [DDHidJoystick allJoysticks];
    DDHidJoystick * joystick;
    NSEnumerator * e = [joysticks objectEnumerator];
    int joystickNumber = 0;
    while (joystick = [e nextObject])
    {
        [p->mJoysticks addObject: joystick];
        [joystick setDelegate: self];
        [joystick performSelectorOnMainThread: @selector(startListening)
                                   withObject: nil
                                waitUntilDone: YES];
        JRLogInfo(@"Found joystick: %@, %d sticks", [joystick productName],
                  [joystick countOfSticks]);
        unsigned i;
        for (i = 0; i < [joystick countOfSticks]; i++)
        {
            DDHidJoystickStick * stick = [joystick objectInSticksAtIndex: i];
            DDHidElement * axis;
            NSString * name;
            axis = [stick xAxisElement];
            name = format(@"J%d X-Axis -", joystickNumber+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_AXIS_NEG, 0)
                         input_code: CODE_OTHER_DIGITAL];
            
            name = format(@"J%d X-Axis +", joystickNumber+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_AXIS_POS, 0)
                         input_code: CODE_OTHER_DIGITAL];
            
            name = format(@"J%d X-Axis", joystickNumber+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_JOYAXIS, 0)
                         input_code: CODE_OTHER_ANALOG_ABSOLUTE];
            
            axis = [stick yAxisElement];
            name = format(@"J%d Y-Axis -", joystickNumber+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_AXIS_NEG, 1)
                         input_code: CODE_OTHER_DIGITAL];
            
            name = format(@"J%d Y-Axis +", joystickNumber+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_AXIS_POS, 1)
                         input_code: CODE_OTHER_DIGITAL];
            
            name = format(@"J%d Y-Axis", joystickNumber+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_JOYAXIS, 1)
                         input_code: CODE_OTHER_ANALOG_ABSOLUTE];
        }
        
        NSArray * buttons = [joystick buttonElements];
        for (i = 0; i < [buttons count]; i++)
        {
            DDHidElement * button = [buttons objectAtIndex: i];

            NSString * name = format(@"J%d Button %d", joystickNumber+1, i+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_BUTTON, i)
                         input_code: CODE_OTHER_DIGITAL];
        }
        
        joystickNumber++;
    }
}

@end

@implementation MameInputController (DDHidJoystickDelegate)

- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            xChanged: (int) value;
{
    joystick_state[0].axes[0] = value*2;
    NSLog(@"X-Changed: %d", value);
}

- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            yChanged: (int) value;

{
    joystick_state[0].axes[1] = value*2;
    NSLog(@"Y-Changed: %d", value);
}

- (void) hidJoystick: (DDHidJoystick *) joystick
          buttonDown: (unsigned) buttonNumber;
{
    joystick_state[0].buttons[buttonNumber] = 1;
    NSLog(@"Button down: %d", buttonNumber);
}

- (void) hidJoystick: (DDHidJoystick *) joystick
            buttonUp: (unsigned) buttonNumber;
{
    joystick_state[0].buttons[buttonNumber] = 0;
    NSLog(@"Button up: %d", buttonNumber);
}

@end

