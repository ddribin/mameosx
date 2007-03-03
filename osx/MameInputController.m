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
    NSMutableArray * mJoystickNames;
    NSMutableArray * mJoysticks;
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

@interface MameInputController (DDHidMouseDelegate)

- (void) hidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX;
- (void) hidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
- (void) hidMouse: (DDHidMouse *) mouse wheelChanged: (SInt32) deltaWheel;
- (void) hidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
- (void) hidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;

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
			value = p->mJoystickStates[joynum].axes[joyindex];
			int top = DDHID_JOYSTICK_VALUE_MAX;
			int bottom = DDHID_JOYSTICK_VALUE_MIN;
			int middle = 0;
            
			// watch for movement greater "a2d_deadzone" along either axis
			// FIXME in the two-axis joystick case, we need to find out
			// the angle. Anything else is unprecise.
			if (codetype == CODETYPE_AXIS_POS)
				value = (value > middle + ((top - middle) * a2d_deadzone));
			else
				value = (value < middle - ((middle - bottom) * a2d_deadzone));
            break;
        }

        // analog joystick axis
		case CODETYPE_JOYAXIS:
			value = ((int *)&p->mJoystickStates[joynum].axes)[joyindex];
            
            if (value < ANALOG_VALUE_MIN)
                value = ANALOG_VALUE_MIN;
			if (value > ANALOG_VALUE_MAX)
                value = ANALOG_VALUE_MAX;
            break;
            
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
    if (!p->mEnabled)
        return 0;
    
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
    [p->mJoystickNames removeAllObjects];
    [p->mJoysticks removeAllObjects];
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
    }
}

@end

@implementation MameInputController (DDHidJoystickDelegate)

- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            xChanged: (int) value;
{
    p->mJoystickStates[[joystick tag]].axes[0] = value*2;
}

- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            yChanged: (int) value;

{
    p->mJoystickStates[[joystick tag]].axes[1] = value*2;
}

- (void) hidJoystick: (DDHidJoystick *) joystick
          buttonDown: (unsigned) buttonNumber;
{
    p->mJoystickStates[[joystick tag]].buttons[buttonNumber] = 1;
}

- (void) hidJoystick: (DDHidJoystick *) joystick
            buttonUp: (unsigned) buttonNumber;
{
    p->mJoystickStates[[joystick tag]].buttons[buttonNumber] = 0;
}

@end


@implementation MameInputController (DDHidMouseDelegate)

- (void) hidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX;
{
    p->mMiceStates[0].x += deltaX;
}

- (void) hidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
{
    p->mMiceStates[0].y += deltaY;
}

- (void) hidMouse: (DDHidMouse *) mouse wheelChanged: (SInt32) deltaWheel;
{
}

- (void) hidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
{
    NSLog(@"Mouse button %d down", buttonNumber);
}

- (void) hidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;
{
    NSLog(@"Mouse button %d up", buttonNumber);
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
