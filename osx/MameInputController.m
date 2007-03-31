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

#include "MameInputTables.h"

typedef struct
{
    int axes[MAX_AXES];
    int buttons[MAX_BUTTONS];
    int povs[MAX_POV];
} JoystickState;

typedef struct
{
    int x;
    int y;
    int buttons[MAX_BUTTONS];
} MouseState;

static float a2d_deadzone = 0.3;

static NSMutableData * utf8Data(NSString * string);
static NSString * format(NSString * format, ...);


@interface MameInputControllerPrivate : NSObject
{
  @public
    os_code_info mCodelist[MAX_KEYS+MAX_JOY];
    int mTotalCodes;
    INT32 mKeyStates[MAME_OSX_NUM_KEYSTATES];
    INT32 mKeyStates2[256];
    NSMutableArray * mJoystickNames;
    NSMutableArray * mJoysticks;
    int mNumberOfKeyboards;
    BOOL mEnabled;
    JoystickState mJoystickStates[MAX_JOYSTICKS];
    MouseState mMiceStates[MAX_MICE];
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
    mJoysticks = [[NSMutableArray alloc] init];
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mJoystickNames release];
    [mJoysticks release];
    
    mJoystickNames = nil;
    mJoysticks = nil;
    [super dealloc];
}

@end

@interface MameInputController (Private)

- (void) initKeyCodes;

- (void) initJoyCodes;

- (void) initMouseCodes;

@end

@interface MameInputController (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;
@end

@interface MameInputController (DDHidJoystickDelegate)

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (unsigned) stick
              xChanged: (int) value;

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (unsigned) stick
              yChanged: (int) value;

- (void) ddhidJoystick: (DDHidJoystick *) joystick
            buttonDown: (unsigned) buttonNumber;

- (void) ddhidJoystick: (DDHidJoystick *) joystick
              buttonUp: (unsigned) buttonNumber;

@end

@interface MameInputController (DDHidMouseDelegate)

- (void) ddhidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX;
- (void) ddhidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
- (void) ddhidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
- (void) ddhidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;

@end


@implementation MameInputController

- (id) init
{
    if ([super init] == nil)
        return nil;
    
    p = [[MameInputControllerPrivate alloc] init];
    p->mEnabled = NO;
    
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
    [p->mJoysticks removeAllObjects];
    [p->mJoystickNames removeAllObjects];

    [self initKeyCodes];
    [self initJoyCodes];
    [self initMouseCodes];

    // terminate array
    memset(&p->mCodelist[p->mTotalCodes], 0, sizeof(p->mCodelist[0]));

    
    int i;
    for (i = 0; i < MAME_OSX_NUM_KEYSTATES; i++)
    {
        p->mKeyStates[i] = 0;
    }
}

- (void) gameFinished;
{
    [p->mJoysticks makeObjectsPerformSelector: @selector(stopListening)];
    [p->mJoysticks removeAllObjects];
    [p->mJoystickNames removeAllObjects];
}

- (const os_code_info *) osd_get_code_list;
{
    return p->mCodelist;
}

- (INT32) getJoyCodeValue: (os_code) joycode;
{
    int joyindex = JOYINDEX(joycode);
    int codetype = CODETYPE(joycode);
    int joynum = JOYNUM(joycode);
    INT32 value = 0;

    switch (codetype)
    {
        case CODETYPE_BUTTON:
            value = p->mJoystickStates[joynum].buttons[joyindex];
            break;

        case CODETYPE_AXIS_POS:
        case CODETYPE_AXIS_NEG:
        {
            int rawValue = p->mJoystickStates[joynum].axes[joyindex];
            int top = DDHID_JOYSTICK_VALUE_MAX;
            int bottom = DDHID_JOYSTICK_VALUE_MIN;
            int middle = 0;
            
            // watch for movement greater "a2d_deadzone" along either axis
            // FIXME in the two-axis joystick case, we need to find out
            // the angle. Anything else is unprecise.
            if (codetype == CODETYPE_AXIS_POS)
                value = (rawValue > middle + ((top - middle) * a2d_deadzone));
            else
                value = (rawValue < middle - ((middle - bottom) * a2d_deadzone));
            break;
        }
            
        // analog joystick axis
        case CODETYPE_JOYAXIS:
            value = ((int *)&p->mJoystickStates[joynum].axes)[joyindex]*2;
            
            if (value < ANALOG_VALUE_MIN)
                value = ANALOG_VALUE_MIN;
            if (value > ANALOG_VALUE_MAX)
                value = ANALOG_VALUE_MAX;
            break;
            
        // anywhere from 0-45 (315) deg to 0+45 (45) deg
        case CODETYPE_POV_UP:
            value = p->mJoystickStates[joynum].povs[joyindex];
            return (value != -1 && (value >= 31500 || value <= 4500));
            
        // anywhere from 90-45 (45) deg to 90+45 (135) deg
        case CODETYPE_POV_RIGHT:
            value = p->mJoystickStates[joynum].povs[joyindex];
            return (value != -1 && (value >= 4500 && value <= 13500));
            
        // anywhere from 180-45 (135) deg to 180+45 (225) deg
        case CODETYPE_POV_DOWN:
            value = p->mJoystickStates[joynum].povs[joyindex];
            return (value != -1 && (value >= 13500 && value <= 22500));
            
        // anywhere from 270-45 (225) deg to 270+45 (315) deg
        case CODETYPE_POV_LEFT:
            value = p->mJoystickStates[joynum].povs[joyindex];
            return (value != -1 && (value >= 22500 && value <= 31500));
            
        case CODETYPE_MOUSEAXIS:
            if (joyindex == 0)
            {
                value = p->mMiceStates[joynum].x * 512;
                p->mMiceStates[joynum].x = 0;
            }
            if (joyindex == 1)
            {
                value = p->mMiceStates[joynum].y * 512;
                p->mMiceStates[joynum].y = 0;
            }
            break;
            
        case CODETYPE_MOUSEBUTTON:
            value = p->mMiceStates[joynum].buttons[joyindex];
            break;
    }

    return value;
}


- (BOOL) enabled;
{
    return p->mEnabled;
}

- (void) setEnabled: (BOOL) enabled;
{
    p->mEnabled = enabled;
}

- (INT32) osd_get_code_value: (os_code) code;
{
    BOOL commandIsDown = ((p->mKeyStates2[kHIDUsage_KeyboardLeftGUI] != 0) ||
                          (p->mKeyStates2[kHIDUsage_KeyboardRightGUI] != 0));

    if (!p->mEnabled || commandIsDown)
        return 0;
    
    INT32 value;
    @synchronized(self)
    {
        if (IS_KEYBOARD_CODE(code))
        {
            value = p->mKeyStates2[code] > 0? 1 : 0;
        }
        else
            return [self getJoyCodeValue: code];
    }
    return value;
}

- (void) osd_customize_inputport_list: (input_port_default_entry *) defaults;
{
    input_port_default_entry *idef = defaults;
    
    // loop over all the defaults
    while (idef->type != IPT_END)
    {
        switch (idef->type)
        {
            case IPT_OSD_3:
                idef->token = "FAST_FORWARD";
                idef->name = "Fast Forward";
                seq_set_1(&idef->defaultseq, KEYCODE_PGDN);
                break;
        }
        
        idef++;
    }
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
    os_code_info * keyTable = key_trans_table;
    // os_code_info * keyTable = codelist;
    while (keyTable[i].name != 0)
    {
        p->mCodelist[p->mTotalCodes] = keyTable[i];
        p->mTotalCodes++;
        i++;
    }
    
    p->mNumberOfKeyboards = 0;
    NSArray * keyboards = [DDHidKeyboard allKeyboards];
    int keyboardCount = MIN([keyboards count], MAX_KEYBOARDS);
    int keyboardNumber;
    for (keyboardNumber = 0; keyboardNumber < keyboardCount; keyboardNumber++)
    {
        DDHidKeyboard * keyboard = [keyboards objectAtIndex: keyboardNumber];
        
        [p->mJoysticks addObject: keyboard];
        p->mNumberOfKeyboards++;
        [keyboard setTag: keyboardNumber];
        [keyboard setDelegate: self];
        [keyboard startListening];
    }
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

- (void) initJoyCodes;
{
    NSArray * joysticks = [DDHidJoystick allJoysticks];
    int joystickCount = MIN([joysticks count], MAX_JOYSTICKS);
    int joystickNumber;
    for (joystickNumber = 0; joystickNumber < joystickCount; joystickNumber++)
    {
        DDHidJoystick * joystick = [joysticks objectAtIndex: joystickNumber];
        
        [p->mJoysticks addObject: joystick];
        [joystick setTag: joystickNumber];
        [joystick setDelegate: self];
        [joystick startListening];

        NSArray * buttons = [joystick buttonElements];
        JRLogInfo(@"Found joystick: %@, %d stick(s), %d button(s)",
                  [joystick productName], [joystick countOfSticks],
                  [buttons count]);
        unsigned i;
        // TODO: Handle more sticks.
        // for (i = 0; i < [joystick countOfSticks]; i++)
        i = 0;
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
            
            int j;
            for (j = 0; j < [stick countOfStickElements]; j++)
            {
                int axisNumber = j+2;
                axis = [stick objectInStickElementsAtIndex: j];
                name = format(@"J%d Axis %d -", joystickNumber+1, axisNumber+1);
                [self add_joylist_entry: name
                                   code: JOYCODE(joystickNumber, CODETYPE_AXIS_NEG, axisNumber)
                             input_code: CODE_OTHER_DIGITAL];
                name = format(@"J%d Axis %d +", joystickNumber+1, axisNumber+1);
                [self add_joylist_entry: name
                                   code: JOYCODE(joystickNumber, CODETYPE_AXIS_POS, axisNumber)

                             input_code: CODE_OTHER_DIGITAL];
                name = format(@"J%d Axis %d", joystickNumber+1, axisNumber+1);
                [self add_joylist_entry: name
                                   code: JOYCODE(joystickNumber, CODETYPE_JOYAXIS, axisNumber)
                             input_code: CODE_OTHER_ANALOG_ABSOLUTE];
            }
            
            for (j = 0; j < [stick countOfPovElements]; j++)
            {
                DDHidElement * pov = [stick objectInPovElementsAtIndex: j];
                name = format(@"J%d Hat Switch U", joystickNumber+1);
                [self add_joylist_entry: name
                                   code: JOYCODE(joystickNumber, CODETYPE_POV_UP, j)
                             input_code: CODE_OTHER_DIGITAL];
                name = format(@"J%d Hat Switch D", joystickNumber+1);
                [self add_joylist_entry: name
                                   code: JOYCODE(joystickNumber, CODETYPE_POV_DOWN, j)
                    
                             input_code: CODE_OTHER_DIGITAL];
                name = format(@"J%d Hat Switch L", joystickNumber+1);
                [self add_joylist_entry: name
                                   code: JOYCODE(joystickNumber, CODETYPE_POV_LEFT, j)
                             input_code: CODE_OTHER_DIGITAL];
                name = format(@"J%d Hat Switch R", joystickNumber+1);
                [self add_joylist_entry: name
                                   code: JOYCODE(joystickNumber, CODETYPE_POV_RIGHT, j)
                             input_code: CODE_OTHER_DIGITAL];
            }
        }
        
        int buttonCount = MIN([buttons count], MAX_BUTTONS);
        for (i = 0; i < buttonCount; i++)
        {
            DDHidElement * button = [buttons objectAtIndex: i];

            NSString * name = format(@"J%d Button %d", joystickNumber+1, i+1);
            [self add_joylist_entry: name
                               code: JOYCODE(joystickNumber, CODETYPE_BUTTON, i)
                         input_code: CODE_OTHER_DIGITAL];
        }
    }
}

- (void) initMouseCodes;
{
    NSArray * mice = [DDHidMouse allMice];
    int mouseCount = MIN([mice count], MAX_MICE);
    int mouseNumber;
    for (mouseNumber = 0; mouseNumber < mouseCount; mouseNumber++)
    {
        DDHidMouse * mouse = [mice objectAtIndex: mouseNumber];
        [p->mJoysticks addObject: mouse];
        [mouse setTag: mouseNumber];
        
        NSArray * buttons = [mouse buttonElements];
        JRLogInfo(@"Found mouse: %@, %d button(s)",
                  [mouse productName], [buttons count]);
        
        [mouse setDelegate: self];
        [mouse startListening];

        DDHidElement * axis;
        NSString * name;

        axis = [mouse xElement];
        name = format(@"M%d X-Axis", mouseNumber+1);
        [self add_joylist_entry: name
                           code: JOYCODE(mouseNumber, CODETYPE_MOUSEAXIS, 0)
                     input_code: CODE_OTHER_DIGITAL];
        
        axis = [mouse xElement];
        name = format(@"M%d Y-Axis", mouseNumber+1);
        [self add_joylist_entry: name
                           code: JOYCODE(mouseNumber, CODETYPE_MOUSEAXIS, 1)
                     input_code: CODE_OTHER_DIGITAL];
        
        int buttonCount = MIN([buttons count], MAX_BUTTONS);
        int i;
        for (i = 0; i < buttonCount; i++)
        {
            DDHidElement * button = [buttons objectAtIndex: i];
            
            NSString * name = format(@"M%d Button %d", mouseNumber+1, i+1);
            [self add_joylist_entry: name
                               code: JOYCODE(mouseNumber, CODETYPE_MOUSEBUTTON, i)
                         input_code: CODE_OTHER_DIGITAL];
        }
    }
}

@end

@implementation MameInputController (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;
{
    uint32_t keyboardBit = 1 << [keyboard tag];
    p->mKeyStates2[usageId] |= keyboardBit;
}

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;
{
    uint32_t keyboardBit = 1 << [keyboard tag];
    p->mKeyStates2[usageId] &= ~keyboardBit;
}

@end

@implementation MameInputController (DDHidJoystickDelegate)

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (unsigned) stick
              xChanged: (int) value;
{
    p->mJoystickStates[[joystick tag]].axes[0] = value;
}

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (unsigned) stick
              yChanged: (int) value;

{
    p->mJoystickStates[[joystick tag]].axes[1] = value;
}

- (void) ddhidJoystick: (DDHidJoystick *) joystick
                 stick: (unsigned) stick
             otherAxis: (unsigned) otherAxis
          valueChanged: (int) value;
{
    int axisNumber = otherAxis+2;
    p->mJoystickStates[[joystick tag]].axes[axisNumber] = value;
}


- (void) ddhidJoystick: (DDHidJoystick *) joystick
                 stick: (unsigned) stick
            povElement: (unsigned) povElement
          valueChanged: (int) value;
{
    p->mJoystickStates[[joystick tag]].povs[povElement] = value;
}

- (void) ddhidJoystick: (DDHidJoystick *) joystick
            buttonDown: (unsigned) buttonNumber;
{
    p->mJoystickStates[[joystick tag]].buttons[buttonNumber] = 1;
}

- (void) ddhidJoystick: (DDHidJoystick *) joystick
              buttonUp: (unsigned) buttonNumber;
{
    p->mJoystickStates[[joystick tag]].buttons[buttonNumber] = 0;
}

@end


@implementation MameInputController (DDHidMouseDelegate)

- (void) ddhidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX;
{
    p->mMiceStates[[mouse tag]].x += deltaX;
}

- (void) ddhidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
{
    p->mMiceStates[[mouse tag]].y += deltaY;
}

- (void) ddhidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
{
    p->mMiceStates[[mouse tag]].buttons[buttonNumber] = 1;
}

- (void) ddhidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;
{
    p->mMiceStates[[mouse tag]].buttons[buttonNumber] = 0;
}

@end


static NSMutableData * utf8Data(NSString * string)
{
    NSMutableData * data = [NSMutableData dataWithData:
        [string dataUsingEncoding: NSUTF8StringEncoding]];
    char null = '\0';
    [data appendBytes: &null length: 1];
    return data;
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
