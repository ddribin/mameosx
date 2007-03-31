/*
 *  MameInputTables.h
 *  mameosx
 *
 *  Created by Dave Dribin on 3/2/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

#include <IOKit/hid/IOHIDUsageTables.h>

#define MAX_KEYS 256
#define MAX_JOY 256

#define MAX_KEYBOARDS       4
#define MAX_MICE            8
#define MAX_JOYSTICKS       8
#define MAX_LIGHTGUNS       2

#define MAX_JOY             256
#define MAX_AXES            8
#define MAX_BUTTONS         32
#define MAX_POV             4

// macros for building/mapping joystick codes
#define JOYCODE(joy, type, index)   ((index) | ((type) << 8) | ((joy) << 12) | 0x80000000)
#define JOYINDEX(joycode)           ((joycode) & 0xff)
#define CODETYPE(joycode)           (((joycode) >> 8) & 0xf)
#define JOYNUM(joycode)             (((joycode) >> 12) & 0xf)

// macros for differentiating the two
#define IS_KEYBOARD_CODE(code)      (((code) & 0x80000000) == 0)
#define IS_JOYSTICK_CODE(code)      (((code) & 0x80000000) != 0)

// joystick types
#define CODETYPE_KEYBOARD           0
#define CODETYPE_AXIS_NEG           1
#define CODETYPE_AXIS_POS           2
#define CODETYPE_POV_UP             3
#define CODETYPE_POV_DOWN           4
#define CODETYPE_POV_LEFT           5
#define CODETYPE_POV_RIGHT          6
#define CODETYPE_BUTTON             7
#define CODETYPE_JOYAXIS            8
#define CODETYPE_MOUSEAXIS          9
#define CODETYPE_MOUSEBUTTON        10
#define CODETYPE_GUNAXIS            11

#define ELEMENTS(x)         (sizeof(x) / sizeof((x)[0]))

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
    {"F6",      FUNC_TO_INDEX(NSF6FunctionKey),         KEYCODE_F6},
    {"F7",      FUNC_TO_INDEX(NSF7FunctionKey),         KEYCODE_F7},
    {"F8",      FUNC_TO_INDEX(NSF8FunctionKey),         KEYCODE_F8},
    {"F9",      FUNC_TO_INDEX(NSF9FunctionKey),         KEYCODE_F9},
    {"F10",     FUNC_TO_INDEX(NSF10FunctionKey),        KEYCODE_F10},
    {"F11",     FUNC_TO_INDEX(NSF11FunctionKey),        KEYCODE_F11},
    {"F12",     FUNC_TO_INDEX(NSF12FunctionKey),        KEYCODE_F12},
    {"F13",     FUNC_TO_INDEX(NSF13FunctionKey),        KEYCODE_F13},
    {"F14",     FUNC_TO_INDEX(NSF14FunctionKey),        KEYCODE_F14},
    {"F15",     FUNC_TO_INDEX(NSF15FunctionKey),        KEYCODE_F15},
    
    
    {"Control", MAME_OSX_CONTROL,   KEYCODE_LCONTROL},
    {"Option",  MAME_OSX_OPTION,    KEYCODE_LALT},
    {"Command", MAME_OSX_COMMAND,   KEYCODE_LWIN},
    {"Shift",   MAME_OSX_SHIFT,     KEYCODE_LSHIFT},
    
    {0,         0,      0}
};

static os_code_info key_trans_table[] =
{
    {"1",       kHIDUsage_Keyboard1,    KEYCODE_1},
    {"2",       kHIDUsage_Keyboard2,    KEYCODE_2},
    {"3",       kHIDUsage_Keyboard3,    KEYCODE_3},
    {"4",       kHIDUsage_Keyboard4,    KEYCODE_4},
    {"5",       kHIDUsage_Keyboard5,    KEYCODE_5},
    {"6",       kHIDUsage_Keyboard6,    KEYCODE_6},
    {"7",       kHIDUsage_Keyboard7,    KEYCODE_7},
    {"8",       kHIDUsage_Keyboard8,    KEYCODE_8},
    {"9",       kHIDUsage_Keyboard9,    KEYCODE_9},
    
    {"A",       kHIDUsage_KeyboardA,    KEYCODE_A},
    {"B",       kHIDUsage_KeyboardB,    KEYCODE_B},
    {"C",       kHIDUsage_KeyboardC,    KEYCODE_C},
    {"D",       kHIDUsage_KeyboardD,    KEYCODE_D},
    {"E",       kHIDUsage_KeyboardE,    KEYCODE_E},
    {"F",       kHIDUsage_KeyboardF,    KEYCODE_F},
    {"G",       kHIDUsage_KeyboardG,    KEYCODE_G},
    {"H",       kHIDUsage_KeyboardH,    KEYCODE_H},
    {"I",       kHIDUsage_KeyboardI,    KEYCODE_I},
    {"J",       kHIDUsage_KeyboardJ,    KEYCODE_J},
    {"K",       kHIDUsage_KeyboardK,    KEYCODE_K},
    {"L",       kHIDUsage_KeyboardL,    KEYCODE_L},
    {"M",       kHIDUsage_KeyboardM,    KEYCODE_M},
    {"N",       kHIDUsage_KeyboardN,    KEYCODE_N},
    {"O",       kHIDUsage_KeyboardO,    KEYCODE_O},
    {"P",       kHIDUsage_KeyboardP,    KEYCODE_P},
    {"Q",       kHIDUsage_KeyboardQ,    KEYCODE_Q},
    {"R",       kHIDUsage_KeyboardR,    KEYCODE_R},
    {"S",       kHIDUsage_KeyboardS,    KEYCODE_S},
    {"T",       kHIDUsage_KeyboardT,    KEYCODE_T},
    {"U",       kHIDUsage_KeyboardU,    KEYCODE_U},
    {"V",       kHIDUsage_KeyboardV,    KEYCODE_V},
    {"W",       kHIDUsage_KeyboardW,    KEYCODE_W},
    {"X",       kHIDUsage_KeyboardX,    KEYCODE_X},
    {"Y",       kHIDUsage_KeyboardY,    KEYCODE_Y},
    {"Z",       kHIDUsage_KeyboardZ,    KEYCODE_Z},
    
    {"ESC",     kHIDUsage_KeyboardEscape,       KEYCODE_ESC},
    {"~",       kHIDUsage_KeyboardGraveAccentAndTilde,
                                                KEYCODE_TILDE},
    {"-",       kHIDUsage_KeyboardHyphen,       KEYCODE_MINUS},
    {"=",       kHIDUsage_KeyboardEqualSign,    KEYCODE_EQUALS},
    {"Backspace", kHIDUsage_KeyboardDeleteOrBackspace,
                                                KEYCODE_BACKSPACE},
    {"Tab",     kHIDUsage_KeyboardTab,          KEYCODE_TAB},
    {"{",       kHIDUsage_KeyboardOpenBracket,  KEYCODE_OPENBRACE},
    {"}",       kHIDUsage_KeyboardCloseBracket, KEYCODE_CLOSEBRACE},
    {"Return",  kHIDUsage_KeyboardReturnOrEnter, KEYCODE_ENTER},
    {":",       kHIDUsage_KeyboardSemicolon,    KEYCODE_COLON},
    {"'",       kHIDUsage_KeyboardQuote,        KEYCODE_QUOTE},
    {"\\",      kHIDUsage_KeyboardBackslash,    KEYCODE_BACKSLASH},
    // KEYCODE_BACKSLASH2
    {",",       kHIDUsage_KeyboardComma,        KEYCODE_COMMA},
    {"Stop",    kHIDUsage_KeyboardStop,         KEYCODE_STOP},
    {"/",       kHIDUsage_KeyboardSlash,        KEYCODE_SLASH},
    {"Space",   kHIDUsage_KeyboardSpacebar,     KEYCODE_SPACE},

    {"Insert",  kHIDUsage_KeyboardInsert,       KEYCODE_INSERT},
    {"Delete",  kHIDUsage_KeyboardDeleteForward, KEYCODE_DEL},
    {"Home",    kHIDUsage_KeyboardHome,         KEYCODE_HOME},
    {"End",     kHIDUsage_KeyboardEnd,          KEYCODE_END},
    {"Page Up", kHIDUsage_KeyboardPageUp,       KEYCODE_PGUP},
    {"Page Down", kHIDUsage_KeyboardPageDown,   KEYCODE_PGDN},
    
    {"Up",      kHIDUsage_KeyboardUpArrow,      KEYCODE_UP},
    {"Down",    kHIDUsage_KeyboardDownArrow,    KEYCODE_DOWN},
    {"Left",    kHIDUsage_KeyboardLeftArrow,    KEYCODE_LEFT},
    {"Right",   kHIDUsage_KeyboardRightArrow,   KEYCODE_RIGHT},
    
    {"F1",      kHIDUsage_KeyboardF1,   KEYCODE_F1},
    {"F2",      kHIDUsage_KeyboardF2,   KEYCODE_F2},
    {"F3",      kHIDUsage_KeyboardF3,   KEYCODE_F3},
    {"F4",      kHIDUsage_KeyboardF4,   KEYCODE_F4},
    {"F5",      kHIDUsage_KeyboardF5,   KEYCODE_F5},
    {"F6",      kHIDUsage_KeyboardF6,   KEYCODE_F6},
    {"F7",      kHIDUsage_KeyboardF7,   KEYCODE_F7},
    {"F8",      kHIDUsage_KeyboardF8,   KEYCODE_F8},
    {"F9",      kHIDUsage_KeyboardF9,   KEYCODE_F9},
    {"F10",     kHIDUsage_KeyboardF10,  KEYCODE_F10},
    {"F11",     kHIDUsage_KeyboardF11,  KEYCODE_F11},
    {"F12",     kHIDUsage_KeyboardF12,  KEYCODE_F12},
    {"F13",     kHIDUsage_KeyboardF13,  KEYCODE_F13},
    {"F14",     kHIDUsage_KeyboardF14,  KEYCODE_F14},
    {"F15",     kHIDUsage_KeyboardF15,  KEYCODE_F15},
    
    {"Keypad 0",    kHIDUsage_Keypad0,  KEYCODE_0_PAD},
    {"Keypad 1",    kHIDUsage_Keypad1,  KEYCODE_1_PAD},
    {"Keypad 2",    kHIDUsage_Keypad2,  KEYCODE_2_PAD},
    {"Keypad 3",    kHIDUsage_Keypad3,  KEYCODE_3_PAD},
    {"Keypad 4",    kHIDUsage_Keypad4,  KEYCODE_4_PAD},
    {"Keypad 5",    kHIDUsage_Keypad5,  KEYCODE_5_PAD},
    {"Keypad 6",    kHIDUsage_Keypad6,  KEYCODE_6_PAD},
    {"Keypad 7",    kHIDUsage_Keypad7,  KEYCODE_7_PAD},
    {"Keypad 8",    kHIDUsage_Keypad8,  KEYCODE_8_PAD},
    {"Keypad 9",    kHIDUsage_Keypad9,  KEYCODE_9_PAD},

    {"Keypad /",    kHIDUsage_KeypadSlash,      KEYCODE_SLASH_PAD},
    {"Keypad *",    kHIDUsage_KeypadAsterisk,   KEYCODE_ASTERISK},
    {"Keypad -",    kHIDUsage_KeypadHyphen,     KEYCODE_MINUS_PAD},
    {"Keypad +",    kHIDUsage_KeypadPlus,       KEYCODE_PLUS_PAD},
    {"Keypad DEL",  kHIDUsage_KeypadNumLock,    KEYCODE_DEL_PAD},
    {"Keypad Enter", kHIDUsage_KeypadEnter,     KEYCODE_ENTER_PAD},

    {"PRTSCR",      kHIDUsage_KeyboardPrintScreen,  KEYCODE_PRTSCR},
    {"Pause",       kHIDUsage_KeyboardPause,        KEYCODE_PAUSE},

    {"L. Control",  kHIDUsage_KeyboardLeftControl,  KEYCODE_LCONTROL},
    {"L. Option",   kHIDUsage_KeyboardLeftAlt,      KEYCODE_LALT},
    // {"L. Command",  kHIDUsage_KeyboardLeftGUI,      KEYCODE_LWIN},
    {"L. Shift",    kHIDUsage_KeyboardLeftShift,    KEYCODE_LSHIFT},

    {"R. Control",  kHIDUsage_KeyboardRightControl, KEYCODE_RCONTROL},
    {"R. Option",   kHIDUsage_KeyboardRightAlt,     KEYCODE_RALT},
    // {"R. Command",  kHIDUsage_KeyboardRightGUI,     KEYCODE_RWIN},
    {"R. Shift",    kHIDUsage_KeyboardRightShift,   KEYCODE_RSHIFT},
    
    {0,         0,      0}
};

// master joystick translation table
static int joy_trans_table[][2] =
{
    // internal code                    MAME code
    { JOYCODE(0, CODETYPE_AXIS_NEG, 0), JOYCODE_1_LEFT },
    { JOYCODE(0, CODETYPE_AXIS_POS, 0), JOYCODE_1_RIGHT },
    { JOYCODE(0, CODETYPE_AXIS_NEG, 1), JOYCODE_1_UP },
    { JOYCODE(0, CODETYPE_AXIS_POS, 1), JOYCODE_1_DOWN },
    { JOYCODE(0, CODETYPE_BUTTON, 0),   JOYCODE_1_BUTTON1 },
    { JOYCODE(0, CODETYPE_BUTTON, 1),   JOYCODE_1_BUTTON2 },
    { JOYCODE(0, CODETYPE_BUTTON, 2),   JOYCODE_1_BUTTON3 },
    { JOYCODE(0, CODETYPE_BUTTON, 3),   JOYCODE_1_BUTTON4 },
    { JOYCODE(0, CODETYPE_BUTTON, 4),   JOYCODE_1_BUTTON5 },
    { JOYCODE(0, CODETYPE_BUTTON, 5),   JOYCODE_1_BUTTON6 },
    { JOYCODE(0, CODETYPE_BUTTON, 6),   JOYCODE_1_BUTTON7 },
    { JOYCODE(0, CODETYPE_BUTTON, 7),   JOYCODE_1_BUTTON8 },
    { JOYCODE(0, CODETYPE_BUTTON, 8),   JOYCODE_1_BUTTON9 },
    { JOYCODE(0, CODETYPE_BUTTON, 9),   JOYCODE_1_BUTTON10 },
    { JOYCODE(0, CODETYPE_BUTTON, 10),  JOYCODE_1_BUTTON11 },
    { JOYCODE(0, CODETYPE_BUTTON, 11),  JOYCODE_1_BUTTON12 },
    { JOYCODE(0, CODETYPE_BUTTON, 12),  JOYCODE_1_BUTTON13 },
    { JOYCODE(0, CODETYPE_BUTTON, 13),  JOYCODE_1_BUTTON14 },
    { JOYCODE(0, CODETYPE_BUTTON, 14),  JOYCODE_1_BUTTON15 },
    { JOYCODE(0, CODETYPE_BUTTON, 15),  JOYCODE_1_BUTTON16 },
    { JOYCODE(0, CODETYPE_JOYAXIS, 0),  JOYCODE_1_ANALOG_X },
    { JOYCODE(0, CODETYPE_JOYAXIS, 1),  JOYCODE_1_ANALOG_Y },
    { JOYCODE(0, CODETYPE_JOYAXIS, 2),  JOYCODE_1_ANALOG_Z },
    
    { JOYCODE(1, CODETYPE_AXIS_NEG, 0), JOYCODE_2_LEFT },
    { JOYCODE(1, CODETYPE_AXIS_POS, 0), JOYCODE_2_RIGHT },
    { JOYCODE(1, CODETYPE_AXIS_NEG, 1), JOYCODE_2_UP },
    { JOYCODE(1, CODETYPE_AXIS_POS, 1), JOYCODE_2_DOWN },
    { JOYCODE(1, CODETYPE_BUTTON, 0),   JOYCODE_2_BUTTON1 },
    { JOYCODE(1, CODETYPE_BUTTON, 1),   JOYCODE_2_BUTTON2 },
    { JOYCODE(1, CODETYPE_BUTTON, 2),   JOYCODE_2_BUTTON3 },
    { JOYCODE(1, CODETYPE_BUTTON, 3),   JOYCODE_2_BUTTON4 },
    { JOYCODE(1, CODETYPE_BUTTON, 4),   JOYCODE_2_BUTTON5 },
    { JOYCODE(1, CODETYPE_BUTTON, 5),   JOYCODE_2_BUTTON6 },
    { JOYCODE(1, CODETYPE_BUTTON, 6),   JOYCODE_2_BUTTON7 },
    { JOYCODE(1, CODETYPE_BUTTON, 7),   JOYCODE_2_BUTTON8 },
    { JOYCODE(1, CODETYPE_BUTTON, 8),   JOYCODE_2_BUTTON9 },
    { JOYCODE(1, CODETYPE_BUTTON, 9),   JOYCODE_2_BUTTON10 },
    { JOYCODE(1, CODETYPE_BUTTON, 10),  JOYCODE_2_BUTTON11 },
    { JOYCODE(1, CODETYPE_BUTTON, 11),  JOYCODE_2_BUTTON12 },
    { JOYCODE(1, CODETYPE_BUTTON, 12),  JOYCODE_2_BUTTON13 },
    { JOYCODE(1, CODETYPE_BUTTON, 13),  JOYCODE_2_BUTTON14 },
    { JOYCODE(1, CODETYPE_BUTTON, 14),  JOYCODE_2_BUTTON15 },
    { JOYCODE(1, CODETYPE_BUTTON, 15),  JOYCODE_2_BUTTON16 },
    { JOYCODE(1, CODETYPE_JOYAXIS, 0),  JOYCODE_2_ANALOG_X },
    { JOYCODE(1, CODETYPE_JOYAXIS, 1),  JOYCODE_2_ANALOG_Y },
    { JOYCODE(1, CODETYPE_JOYAXIS, 2),  JOYCODE_2_ANALOG_Z },
    
    { JOYCODE(2, CODETYPE_AXIS_NEG, 0), JOYCODE_3_LEFT },
    { JOYCODE(2, CODETYPE_AXIS_POS, 0), JOYCODE_3_RIGHT },
    { JOYCODE(2, CODETYPE_AXIS_NEG, 1), JOYCODE_3_UP },
    { JOYCODE(2, CODETYPE_AXIS_POS, 1), JOYCODE_3_DOWN },
    { JOYCODE(2, CODETYPE_BUTTON, 0),   JOYCODE_3_BUTTON1 },
    { JOYCODE(2, CODETYPE_BUTTON, 1),   JOYCODE_3_BUTTON2 },
    { JOYCODE(2, CODETYPE_BUTTON, 2),   JOYCODE_3_BUTTON3 },
    { JOYCODE(2, CODETYPE_BUTTON, 3),   JOYCODE_3_BUTTON4 },
    { JOYCODE(2, CODETYPE_BUTTON, 4),   JOYCODE_3_BUTTON5 },
    { JOYCODE(2, CODETYPE_BUTTON, 5),   JOYCODE_3_BUTTON6 },
    { JOYCODE(2, CODETYPE_BUTTON, 6),   JOYCODE_3_BUTTON7 },
    { JOYCODE(2, CODETYPE_BUTTON, 7),   JOYCODE_3_BUTTON8 },
    { JOYCODE(2, CODETYPE_BUTTON, 8),   JOYCODE_3_BUTTON9 },
    { JOYCODE(2, CODETYPE_BUTTON, 9),   JOYCODE_3_BUTTON10 },
    { JOYCODE(2, CODETYPE_BUTTON, 10),  JOYCODE_3_BUTTON11 },
    { JOYCODE(2, CODETYPE_BUTTON, 11),  JOYCODE_3_BUTTON12 },
    { JOYCODE(2, CODETYPE_BUTTON, 12),  JOYCODE_3_BUTTON13 },
    { JOYCODE(2, CODETYPE_BUTTON, 13),  JOYCODE_3_BUTTON14 },
    { JOYCODE(2, CODETYPE_BUTTON, 14),  JOYCODE_3_BUTTON15 },
    { JOYCODE(2, CODETYPE_BUTTON, 15),  JOYCODE_3_BUTTON16 },
    { JOYCODE(2, CODETYPE_JOYAXIS, 0),  JOYCODE_3_ANALOG_X },
    { JOYCODE(2, CODETYPE_JOYAXIS, 1),  JOYCODE_3_ANALOG_Y },
    { JOYCODE(2, CODETYPE_JOYAXIS, 2),  JOYCODE_3_ANALOG_Z },
    
    { JOYCODE(3, CODETYPE_AXIS_NEG, 0), JOYCODE_4_LEFT },
    { JOYCODE(3, CODETYPE_AXIS_POS, 0), JOYCODE_4_RIGHT },
    { JOYCODE(3, CODETYPE_AXIS_NEG, 1), JOYCODE_4_UP },
    { JOYCODE(3, CODETYPE_AXIS_POS, 1), JOYCODE_4_DOWN },
    { JOYCODE(3, CODETYPE_BUTTON, 0),   JOYCODE_4_BUTTON1 },
    { JOYCODE(3, CODETYPE_BUTTON, 1),   JOYCODE_4_BUTTON2 },
    { JOYCODE(3, CODETYPE_BUTTON, 2),   JOYCODE_4_BUTTON3 },
    { JOYCODE(3, CODETYPE_BUTTON, 3),   JOYCODE_4_BUTTON4 },
    { JOYCODE(3, CODETYPE_BUTTON, 4),   JOYCODE_4_BUTTON5 },
    { JOYCODE(3, CODETYPE_BUTTON, 5),   JOYCODE_4_BUTTON6 },
    { JOYCODE(3, CODETYPE_BUTTON, 6),   JOYCODE_4_BUTTON7 },
    { JOYCODE(3, CODETYPE_BUTTON, 7),   JOYCODE_4_BUTTON8 },
    { JOYCODE(3, CODETYPE_BUTTON, 8),   JOYCODE_4_BUTTON9 },
    { JOYCODE(3, CODETYPE_BUTTON, 9),   JOYCODE_4_BUTTON10 },
    { JOYCODE(3, CODETYPE_BUTTON, 10),  JOYCODE_4_BUTTON11 },
    { JOYCODE(3, CODETYPE_BUTTON, 11),  JOYCODE_4_BUTTON12 },
    { JOYCODE(3, CODETYPE_BUTTON, 12),  JOYCODE_4_BUTTON13 },
    { JOYCODE(3, CODETYPE_BUTTON, 13),  JOYCODE_4_BUTTON14 },
    { JOYCODE(3, CODETYPE_BUTTON, 14),  JOYCODE_4_BUTTON15 },
    { JOYCODE(3, CODETYPE_BUTTON, 15),  JOYCODE_4_BUTTON16 },
    { JOYCODE(3, CODETYPE_JOYAXIS, 0),  JOYCODE_4_ANALOG_X },
    { JOYCODE(3, CODETYPE_JOYAXIS, 1),  JOYCODE_4_ANALOG_Y },
    { JOYCODE(3, CODETYPE_JOYAXIS, 2),  JOYCODE_4_ANALOG_Z },
    
    { JOYCODE(4, CODETYPE_AXIS_NEG, 0), JOYCODE_5_LEFT },
    { JOYCODE(4, CODETYPE_AXIS_POS, 0), JOYCODE_5_RIGHT },
    { JOYCODE(4, CODETYPE_AXIS_NEG, 1), JOYCODE_5_UP },
    { JOYCODE(4, CODETYPE_AXIS_POS, 1), JOYCODE_5_DOWN },
    { JOYCODE(4, CODETYPE_BUTTON, 0),   JOYCODE_5_BUTTON1 },
    { JOYCODE(4, CODETYPE_BUTTON, 1),   JOYCODE_5_BUTTON2 },
    { JOYCODE(4, CODETYPE_BUTTON, 2),   JOYCODE_5_BUTTON3 },
    { JOYCODE(4, CODETYPE_BUTTON, 3),   JOYCODE_5_BUTTON4 },
    { JOYCODE(4, CODETYPE_BUTTON, 4),   JOYCODE_5_BUTTON5 },
    { JOYCODE(4, CODETYPE_BUTTON, 5),   JOYCODE_5_BUTTON6 },
    { JOYCODE(4, CODETYPE_BUTTON, 6),   JOYCODE_5_BUTTON7 },
    { JOYCODE(4, CODETYPE_BUTTON, 7),   JOYCODE_5_BUTTON8 },
    { JOYCODE(4, CODETYPE_BUTTON, 8),   JOYCODE_5_BUTTON9 },
    { JOYCODE(4, CODETYPE_BUTTON, 9),   JOYCODE_5_BUTTON10 },
    { JOYCODE(4, CODETYPE_BUTTON, 10),  JOYCODE_5_BUTTON11 },
    { JOYCODE(4, CODETYPE_BUTTON, 11),  JOYCODE_5_BUTTON12 },
    { JOYCODE(4, CODETYPE_BUTTON, 12),  JOYCODE_5_BUTTON13 },
    { JOYCODE(4, CODETYPE_BUTTON, 13),  JOYCODE_5_BUTTON14 },
    { JOYCODE(4, CODETYPE_BUTTON, 14),  JOYCODE_5_BUTTON15 },
    { JOYCODE(4, CODETYPE_BUTTON, 15),  JOYCODE_5_BUTTON16 },
    { JOYCODE(4, CODETYPE_JOYAXIS, 0),  JOYCODE_5_ANALOG_X },
    { JOYCODE(4, CODETYPE_JOYAXIS, 1),  JOYCODE_5_ANALOG_Y },
    { JOYCODE(4, CODETYPE_JOYAXIS, 2),  JOYCODE_5_ANALOG_Z },
    
    { JOYCODE(5, CODETYPE_AXIS_NEG, 0), JOYCODE_6_LEFT },
    { JOYCODE(5, CODETYPE_AXIS_POS, 0), JOYCODE_6_RIGHT },
    { JOYCODE(5, CODETYPE_AXIS_NEG, 1), JOYCODE_6_UP },
    { JOYCODE(5, CODETYPE_AXIS_POS, 1), JOYCODE_6_DOWN },
    { JOYCODE(5, CODETYPE_BUTTON, 0),   JOYCODE_6_BUTTON1 },
    { JOYCODE(5, CODETYPE_BUTTON, 1),   JOYCODE_6_BUTTON2 },
    { JOYCODE(5, CODETYPE_BUTTON, 2),   JOYCODE_6_BUTTON3 },
    { JOYCODE(5, CODETYPE_BUTTON, 3),   JOYCODE_6_BUTTON4 },
    { JOYCODE(5, CODETYPE_BUTTON, 4),   JOYCODE_6_BUTTON5 },
    { JOYCODE(5, CODETYPE_BUTTON, 5),   JOYCODE_6_BUTTON6 },
    { JOYCODE(5, CODETYPE_BUTTON, 6),   JOYCODE_6_BUTTON7 },
    { JOYCODE(5, CODETYPE_BUTTON, 7),   JOYCODE_6_BUTTON8 },
    { JOYCODE(5, CODETYPE_BUTTON, 8),   JOYCODE_6_BUTTON9 },
    { JOYCODE(5, CODETYPE_BUTTON, 9),   JOYCODE_6_BUTTON10 },
    { JOYCODE(5, CODETYPE_BUTTON, 10),  JOYCODE_6_BUTTON11 },
    { JOYCODE(5, CODETYPE_BUTTON, 11),  JOYCODE_6_BUTTON12 },
    { JOYCODE(5, CODETYPE_BUTTON, 12),  JOYCODE_6_BUTTON13 },
    { JOYCODE(5, CODETYPE_BUTTON, 13),  JOYCODE_6_BUTTON14 },
    { JOYCODE(5, CODETYPE_BUTTON, 14),  JOYCODE_6_BUTTON15 },
    { JOYCODE(5, CODETYPE_BUTTON, 15),  JOYCODE_6_BUTTON16 },
    { JOYCODE(5, CODETYPE_JOYAXIS, 0),  JOYCODE_6_ANALOG_X },
    { JOYCODE(5, CODETYPE_JOYAXIS, 1),  JOYCODE_6_ANALOG_Y },
    { JOYCODE(5, CODETYPE_JOYAXIS, 2),  JOYCODE_6_ANALOG_Z },
    
    { JOYCODE(6, CODETYPE_AXIS_NEG, 0), JOYCODE_7_LEFT },
    { JOYCODE(6, CODETYPE_AXIS_POS, 0), JOYCODE_7_RIGHT },
    { JOYCODE(6, CODETYPE_AXIS_NEG, 1), JOYCODE_7_UP },
    { JOYCODE(6, CODETYPE_AXIS_POS, 1), JOYCODE_7_DOWN },
    { JOYCODE(6, CODETYPE_BUTTON, 0),   JOYCODE_7_BUTTON1 },
    { JOYCODE(6, CODETYPE_BUTTON, 1),   JOYCODE_7_BUTTON2 },
    { JOYCODE(6, CODETYPE_BUTTON, 2),   JOYCODE_7_BUTTON3 },
    { JOYCODE(6, CODETYPE_BUTTON, 3),   JOYCODE_7_BUTTON4 },
    { JOYCODE(6, CODETYPE_BUTTON, 4),   JOYCODE_7_BUTTON5 },
    { JOYCODE(6, CODETYPE_BUTTON, 5),   JOYCODE_7_BUTTON6 },
    { JOYCODE(6, CODETYPE_BUTTON, 6),   JOYCODE_7_BUTTON7 },
    { JOYCODE(6, CODETYPE_BUTTON, 7),   JOYCODE_7_BUTTON8 },
    { JOYCODE(6, CODETYPE_BUTTON, 8),   JOYCODE_7_BUTTON9 },
    { JOYCODE(6, CODETYPE_BUTTON, 9),   JOYCODE_7_BUTTON10 },
    { JOYCODE(6, CODETYPE_BUTTON, 10),  JOYCODE_7_BUTTON11 },
    { JOYCODE(6, CODETYPE_BUTTON, 11),  JOYCODE_7_BUTTON12 },
    { JOYCODE(6, CODETYPE_BUTTON, 12),  JOYCODE_7_BUTTON13 },
    { JOYCODE(6, CODETYPE_BUTTON, 13),  JOYCODE_7_BUTTON14 },
    { JOYCODE(6, CODETYPE_BUTTON, 14),  JOYCODE_7_BUTTON15 },
    { JOYCODE(6, CODETYPE_BUTTON, 15),  JOYCODE_7_BUTTON16 },
    { JOYCODE(6, CODETYPE_JOYAXIS, 0),  JOYCODE_7_ANALOG_X },
    { JOYCODE(6, CODETYPE_JOYAXIS, 1),  JOYCODE_7_ANALOG_Y },
    { JOYCODE(6, CODETYPE_JOYAXIS, 2),  JOYCODE_7_ANALOG_Z },
    
    { JOYCODE(7, CODETYPE_AXIS_NEG, 0), JOYCODE_8_LEFT },
    { JOYCODE(7, CODETYPE_AXIS_POS, 0), JOYCODE_8_RIGHT },
    { JOYCODE(7, CODETYPE_AXIS_NEG, 1), JOYCODE_8_UP },
    { JOYCODE(7, CODETYPE_AXIS_POS, 1), JOYCODE_8_DOWN },
    { JOYCODE(7, CODETYPE_BUTTON, 0),   JOYCODE_8_BUTTON1 },
    { JOYCODE(7, CODETYPE_BUTTON, 1),   JOYCODE_8_BUTTON2 },
    { JOYCODE(7, CODETYPE_BUTTON, 2),   JOYCODE_8_BUTTON3 },
    { JOYCODE(7, CODETYPE_BUTTON, 3),   JOYCODE_8_BUTTON4 },
    { JOYCODE(7, CODETYPE_BUTTON, 4),   JOYCODE_8_BUTTON5 },
    { JOYCODE(7, CODETYPE_BUTTON, 5),   JOYCODE_8_BUTTON6 },
    { JOYCODE(7, CODETYPE_BUTTON, 6),   JOYCODE_8_BUTTON7 },
    { JOYCODE(7, CODETYPE_BUTTON, 7),   JOYCODE_8_BUTTON8 },
    { JOYCODE(7, CODETYPE_BUTTON, 8),   JOYCODE_8_BUTTON9 },
    { JOYCODE(7, CODETYPE_BUTTON, 9),   JOYCODE_8_BUTTON10 },
    { JOYCODE(7, CODETYPE_BUTTON, 10),  JOYCODE_8_BUTTON11 },
    { JOYCODE(7, CODETYPE_BUTTON, 11),  JOYCODE_8_BUTTON12 },
    { JOYCODE(7, CODETYPE_BUTTON, 12),  JOYCODE_8_BUTTON13 },
    { JOYCODE(7, CODETYPE_BUTTON, 13),  JOYCODE_8_BUTTON14 },
    { JOYCODE(7, CODETYPE_BUTTON, 14),  JOYCODE_8_BUTTON15 },
    { JOYCODE(7, CODETYPE_BUTTON, 15),  JOYCODE_8_BUTTON16 },
    { JOYCODE(7, CODETYPE_JOYAXIS, 0),  JOYCODE_8_ANALOG_X },
    { JOYCODE(7, CODETYPE_JOYAXIS, 1),  JOYCODE_8_ANALOG_Y },
    { JOYCODE(7, CODETYPE_JOYAXIS, 2),  JOYCODE_8_ANALOG_Z },
    
    { JOYCODE(0, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_1_BUTTON1 },
    { JOYCODE(0, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_1_BUTTON2 },
    { JOYCODE(0, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_1_BUTTON3 },
    { JOYCODE(0, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_1_BUTTON4 },
    { JOYCODE(0, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_1_BUTTON5 },
    { JOYCODE(0, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_1_ANALOG_X },
    { JOYCODE(0, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_1_ANALOG_Y },
    { JOYCODE(0, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_1_ANALOG_Z },
    
    { JOYCODE(1, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_2_BUTTON1 },
    { JOYCODE(1, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_2_BUTTON2 },
    { JOYCODE(1, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_2_BUTTON3 },
    { JOYCODE(1, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_2_BUTTON4 },
    { JOYCODE(1, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_2_BUTTON5 },
    { JOYCODE(1, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_2_ANALOG_X },
    { JOYCODE(1, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_2_ANALOG_Y },
    { JOYCODE(1, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_2_ANALOG_Z },
    
    { JOYCODE(2, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_3_BUTTON1 },
    { JOYCODE(2, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_3_BUTTON2 },
    { JOYCODE(2, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_3_BUTTON3 },
    { JOYCODE(2, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_3_BUTTON4 },
    { JOYCODE(2, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_3_BUTTON5 },
    { JOYCODE(2, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_3_ANALOG_X },
    { JOYCODE(2, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_3_ANALOG_Y },
    { JOYCODE(2, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_3_ANALOG_Z },
    
    { JOYCODE(3, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_4_BUTTON1 },
    { JOYCODE(3, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_4_BUTTON2 },
    { JOYCODE(3, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_4_BUTTON3 },
    { JOYCODE(3, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_4_BUTTON4 },
    { JOYCODE(3, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_4_BUTTON5 },
    { JOYCODE(3, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_4_ANALOG_X },
    { JOYCODE(3, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_4_ANALOG_Y },
    { JOYCODE(3, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_4_ANALOG_Z },
    
    { JOYCODE(4, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_5_BUTTON1 },
    { JOYCODE(4, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_5_BUTTON2 },
    { JOYCODE(4, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_5_BUTTON3 },
    { JOYCODE(4, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_5_BUTTON4 },
    { JOYCODE(4, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_5_BUTTON5 },
    { JOYCODE(4, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_5_ANALOG_X },
    { JOYCODE(4, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_5_ANALOG_Y },
    { JOYCODE(4, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_5_ANALOG_Z },
    
    { JOYCODE(5, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_6_BUTTON1 },
    { JOYCODE(5, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_6_BUTTON2 },
    { JOYCODE(5, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_6_BUTTON3 },
    { JOYCODE(5, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_6_BUTTON4 },
    { JOYCODE(5, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_6_BUTTON5 },
    { JOYCODE(5, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_6_ANALOG_X },
    { JOYCODE(5, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_6_ANALOG_Y },
    { JOYCODE(5, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_6_ANALOG_Z },
    
    { JOYCODE(6, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_7_BUTTON1 },
    { JOYCODE(6, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_7_BUTTON2 },
    { JOYCODE(6, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_7_BUTTON3 },
    { JOYCODE(6, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_7_BUTTON4 },
    { JOYCODE(6, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_7_BUTTON5 },
    { JOYCODE(6, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_7_ANALOG_X },
    { JOYCODE(6, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_7_ANALOG_Y },
    { JOYCODE(6, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_7_ANALOG_Z },
    
    { JOYCODE(7, CODETYPE_MOUSEBUTTON, 0),  MOUSECODE_8_BUTTON1 },
    { JOYCODE(7, CODETYPE_MOUSEBUTTON, 1),  MOUSECODE_8_BUTTON2 },
    { JOYCODE(7, CODETYPE_MOUSEBUTTON, 2),  MOUSECODE_8_BUTTON3 },
    { JOYCODE(7, CODETYPE_MOUSEBUTTON, 3),  MOUSECODE_8_BUTTON4 },
    { JOYCODE(7, CODETYPE_MOUSEBUTTON, 4),  MOUSECODE_8_BUTTON5 },
    { JOYCODE(7, CODETYPE_MOUSEAXIS, 0),    MOUSECODE_8_ANALOG_X },
    { JOYCODE(7, CODETYPE_MOUSEAXIS, 1),    MOUSECODE_8_ANALOG_Y },
    { JOYCODE(7, CODETYPE_MOUSEAXIS, 2),    MOUSECODE_8_ANALOG_Z },
    
    { JOYCODE(0, CODETYPE_GUNAXIS, 0),      GUNCODE_1_ANALOG_X },
    { JOYCODE(0, CODETYPE_GUNAXIS, 1),      GUNCODE_1_ANALOG_Y },
    
    { JOYCODE(1, CODETYPE_GUNAXIS, 0),      GUNCODE_2_ANALOG_X },
    { JOYCODE(1, CODETYPE_GUNAXIS, 1),      GUNCODE_2_ANALOG_Y },
    
    { JOYCODE(2, CODETYPE_GUNAXIS, 0),      GUNCODE_3_ANALOG_X },
    { JOYCODE(2, CODETYPE_GUNAXIS, 1),      GUNCODE_3_ANALOG_Y },
    
    { JOYCODE(3, CODETYPE_GUNAXIS, 0),      GUNCODE_4_ANALOG_X },
    { JOYCODE(3, CODETYPE_GUNAXIS, 1),      GUNCODE_4_ANALOG_Y },
    
    { JOYCODE(4, CODETYPE_GUNAXIS, 0),      GUNCODE_5_ANALOG_X },
    { JOYCODE(4, CODETYPE_GUNAXIS, 1),      GUNCODE_5_ANALOG_Y },
    
    { JOYCODE(5, CODETYPE_GUNAXIS, 0),      GUNCODE_6_ANALOG_X },
    { JOYCODE(5, CODETYPE_GUNAXIS, 1),      GUNCODE_6_ANALOG_Y },
    
    { JOYCODE(6, CODETYPE_GUNAXIS, 0),      GUNCODE_7_ANALOG_X },
    { JOYCODE(6, CODETYPE_GUNAXIS, 1),      GUNCODE_7_ANALOG_Y },
    
    { JOYCODE(7, CODETYPE_GUNAXIS, 0),      GUNCODE_8_ANALOG_X },
    { JOYCODE(7, CODETYPE_GUNAXIS, 1),      GUNCODE_8_ANALOG_Y },
};
