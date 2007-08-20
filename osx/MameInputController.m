/*
 * Copyright (c) 2006-2007 Dave Dribin
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

enum
{
    POVDIR_LEFT = 0,
    POVDIR_RIGHT,
    POVDIR_UP,
    POVDIR_DOWN
};

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

static NSMutableData * utf8Data(NSString * string);
static NSString * format(NSString * format, ...);


@interface MameInputControllerPrivate : NSObject
{
  @public
    int mTotalCodes;
    uint32_t mKeyStates[MAX_KEYS];
    NSMutableArray * mDeviceNames;
    NSMutableArray * mDevices;
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
    
    mDeviceNames = [[NSMutableArray alloc] init];
    mDevices = [[NSMutableArray alloc] init];
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mDeviceNames release];
    [mDevices release];
    
    mDeviceNames = nil;
    mDevices = nil;
    [super dealloc];
}

@end

@interface MameInputController (Private)

- (BOOL) addDevice: (DDHidDevice *) device tag: (int) tag;

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
    [p->mDevices removeAllObjects];
    [p->mDeviceNames removeAllObjects];

    [self initKeyCodes];
    [self initJoyCodes];
    [self initMouseCodes];

    int i;
    for (i = 0; i < 256; i++)
    {
        p->mKeyStates[i] = 0;
    }
}

- (void) gameFinished;
{
    [p->mDevices makeObjectsPerformSelector: @selector(stopListening)];
    [p->mDevices removeAllObjects];
    [p->mDeviceNames removeAllObjects];
}

- (BOOL) enabled;
{
    return p->mEnabled;
}

- (void) setEnabled: (BOOL) enabled;
{
    p->mEnabled = enabled;
}

- (void) osd_customize_inputport_list: (input_port_default_entry *) defaults;
{
    input_port_default_entry *idef = defaults;
    
    // loop over all the defaults
    while (idef->type != IPT_END)
    {
        switch (idef->type)
        {
            case IPT_UI_FAST_FORWARD:
                idef->token = "FAST_FORWARD";
                idef->name = "Fast Forward";
                input_seq_set_1(&idef->defaultseq, KEYCODE_PGDN);
                break;
        }
        
        idef++;
    }
}

@end

@implementation MameInputController (Private)

- (BOOL) addDevice: (DDHidDevice *) device tag: (int) tag;
{
    BOOL success = NO;
    @try
    {
        [device setTag: tag];
        [device startListening];
        
        // Make sure to add the object last, to ensure it was able to start
        // listening
        [p->mDevices addObject: device];
        success = YES;
    }
    @catch (id e)
    {
        JRLogInfo(@"addDevice exception: %@", e);
        success = NO;
    }
    return success;
}

static INT32 keyboardGetState(void *device_internal, void *item_internal)
{
    uint32_t tag = (uint32_t) device_internal;
    uint32_t keyboardBit = 1 << tag;
    uint32_t * keyState = (uint32_t *) item_internal;
    return ((*keyState & keyboardBit) != 0)? 1 : 0;
}

- (void) initKeyCodes;
{
    int keyboardTag = 0;
    NSArray * keyboards = [DDHidKeyboard allKeyboards];
    int keyboardCount = MIN([keyboards count], MAX_KEYBOARDS);
    int keyboardNumber;
    for (keyboardNumber = 0; keyboardNumber < keyboardCount; keyboardNumber++)
    {
        DDHidKeyboard * keyboard = [keyboards objectAtIndex: keyboardNumber];
        JRLogInfo(@"Found keyboard: %@ (%@)",
                  [keyboard productName], [keyboard manufacturer]);
        if (![self addDevice: keyboard tag: keyboardTag])
        {
            JRLogInfo(@"Could not add keyboard, skipping");
            continue;
        }
        [keyboard setDelegate: self];
        
        NSString * name = [NSString stringWithFormat: @"Keyboard %d", keyboardTag];
        JRLogInfo(@"Adding keyboard device: %@", name);
        input_device * device = input_device_add(DEVICE_CLASS_KEYBOARD,
                                                 [name UTF8String],
                                                 (void *) keyboardTag);
        
        
        int i = 0;
        while (sKeyboardTranslationTable[i].name != 0)
        {
            os_code_info * currentKey = &sKeyboardTranslationTable[i];
            uint32_t * keyState = &p->mKeyStates[currentKey->oscode];
            input_device_item_add(device,
                                  currentKey->name,
                                  keyState,
                                  currentKey->itemId,
                                  keyboardGetState);

            i++;
        }
        
        keyboardTag++;
    }
}

static INT32 joystickAxisGetState(void *device_internal, void *item_internal)
{
    int * axisState = (INT32 *) item_internal;
    return (*axisState);
}

static INT32 joystickPovGetState(void *device_internal, void *item_internal)
{
    JoystickState * joystickState = device_internal;
    int povnum = (FPTR)item_internal / 4;
    int povdir = (FPTR)item_internal % 4;
    
    int value = joystickState->povs[povnum];
    switch (povdir)
    {
        // anywhere from 0-45 (315) deg to 0+45 (45) deg
        case POVDIR_UP:
            return (value != -1 && (value >= 31500 || value <= 4500));
            
        // anywhere from 90-45 (45) deg to 90+45 (135) deg
        case POVDIR_RIGHT:
            return (value != -1 && (value >= 4500 && value <= 13500));
            
        // anywhere from 180-45 (135) deg to 180+45 (225) deg
        case POVDIR_DOWN:
            return (value != -1 && (value >= 13500 && value <= 22500));
            
        // anywhere from 270-45 (225) deg to 270+45 (315) deg
        case POVDIR_LEFT:
            return (value != -1 && (value >= 22500 && value <= 31500));
    }
    return 0;
}

static INT32 joystickButtonGetState(void *device_internal, void *item_internal)
{
    int * buttonState = (INT32 *) item_internal;
    return (*buttonState);
}

- (void) initJoyCodes;
{
    int joystickTag = 0;
    NSArray * joysticks = [DDHidJoystick allJoysticks];
    int joystickCount = MIN([joysticks count], MAX_JOYSTICKS);
    int joystickNumber;
    for (joystickNumber = 0; joystickNumber < joystickCount; joystickNumber++)
    {
        DDHidJoystick * joystick = [joysticks objectAtIndex: joystickNumber];
        NSArray * buttons = [joystick buttonElements];
        JRLogInfo(@"Found joystick: %@ (%@), %d stick(s), %d button(s)",
                  [joystick productName], [joystick manufacturer],
                  [joystick countOfSticks], [buttons count]);

        if (![self addDevice: joystick tag: joystickTag])
        {
            JRLogInfo(@"Could not add joystick, skipping");
            continue;
        }
        [joystick setDelegate: self];
        
        NSString * name = [NSString stringWithFormat: @"Joystick %d", joystickTag];
        JRLogInfo(@"Adding joystick device: %@", name);
        JoystickState * joystickState = &p->mJoystickStates[joystickTag];
        input_device * device = input_device_add(DEVICE_CLASS_JOYSTICK,
                                                 [name UTF8String],
                                                 (void *) joystickState);
        

        unsigned i;
        // TODO: Handle more sticks.
        // for (i = 0; i < [joystick countOfSticks]; i++)
        i = 0;
        {
            DDHidJoystickStick * stick = [joystick objectInSticksAtIndex: i];
            NSString * name;
            int * axisState;
            
            name = @"X-Axis";
            axisState = &joystickState->axes[0];
            input_device_item_add(device,
                                  [name UTF8String],
                                  axisState,
                                  ITEM_ID_XAXIS,
                                  joystickAxisGetState);
            
            name = @"Y-Axis";
            axisState = &joystickState->axes[1];
            input_device_item_add(device,
                                  [name UTF8String],
                                  axisState,
                                  ITEM_ID_YAXIS,
                                  joystickAxisGetState);
            
            int j;
            for (j = 0; j < [stick countOfStickElements]; j++)
            {
                int axisNumber = j+2;
                name = format(@"Axis %d", axisNumber+1);
                axisState = &joystickState->axes[axisNumber];
                input_device_item_add(device,
                                      [name UTF8String],
                                      axisState,
                                      ITEM_ID_XAXIS + axisNumber,
                                      joystickAxisGetState);
            }
            
            for (j = 0; j < [stick countOfPovElements]; j++)
            {
                DDHidElement * pov = [stick objectInPovElementsAtIndex: j];
                name = format(@"Hat Switch %d U", j+1);
                input_device_item_add(device,
                                      [name UTF8String],
                                      (void *) (j * 4 + POVDIR_UP),
                                      ITEM_ID_OTHER_SWITCH,
                                      joystickPovGetState);
                
                name = format(@"Hat Switch %d D", j+1);
                input_device_item_add(device,
                                      [name UTF8String],
                                      (void *) (j * 4 + POVDIR_DOWN),
                                      ITEM_ID_OTHER_SWITCH,
                                      joystickPovGetState);
                
                name = format(@"Hat Switch %d L", j+1);
                input_device_item_add(device,
                                      [name UTF8String],
                                      (void *) (j * 4 + POVDIR_LEFT),
                                      ITEM_ID_OTHER_SWITCH,
                                      joystickPovGetState);

                name = format(@"Hat Switch %d R", j+1);
                input_device_item_add(device,
                                      [name UTF8String],
                                      (void *) (j * 4 + POVDIR_RIGHT),
                                      ITEM_ID_OTHER_SWITCH,
                                      joystickPovGetState);
            }
        }
        
        int buttonCount = MIN([buttons count], MAX_BUTTONS);
        for (i = 0; i < buttonCount; i++)
        {
            DDHidElement * button = [buttons objectAtIndex: i];

            NSString * name = format(@"Button %d", i+1);
            int * buttonState = &joystickState->buttons[i];
            input_device_item_add(device,
                                  [name UTF8String],
                                  buttonState,
                                  ITEM_ID_BUTTON1 + i,
                                  joystickButtonGetState);
        }
        joystickTag++;
    }
}

static INT32 mouseAxisGetState(void *device_internal, void *item_internal)
{
    INT32 * axisState = (INT32 *) item_internal;
    INT32 result = (*axisState) * INPUT_RELATIVE_PER_PIXEL;
    *axisState = 0;
    return result;
}

static INT32 mouseButtonGetState(void *device_internal, void *item_internal)
{
    int * buttonState = (INT32 *) item_internal;
    return (*buttonState);
}

- (void) initMouseCodes;
{
    int mouseTag = 0;
    NSArray * mice = [DDHidMouse allMice];
    int mouseCount = MIN([mice count], MAX_MICE);
    int mouseNumber;
    for (mouseNumber = 0; mouseNumber < mouseCount; mouseNumber++)
    {
        DDHidMouse * mouse = [mice objectAtIndex: mouseNumber];
        NSArray * buttons = [mouse buttonElements];
        JRLogInfo(@"Found mouse: %@ (%@), %d button(s)",
                  [mouse productName], [mouse manufacturer], [buttons count]);
        if (![self addDevice: mouse tag: mouseTag])
        {
            JRLogInfo(@"Could not add mouse, skipping");
            continue;
        }
        [mouse setDelegate: self];

        NSString * name = [NSString stringWithFormat: @"Mouse %d", mouseTag];
        JRLogInfo(@"Adding mouse device: %@", name);
        MouseState * mouseState = &p->mMiceStates[mouseTag];
        input_device * device = input_device_add(DEVICE_CLASS_MOUSE,
                                                 [name UTF8String],
                                                 (void *) mouseState);
        
        DDHidElement * axis;

        axis = [mouse xElement];
        name = @"X-Axis";
        int * axisState =  &mouseState->x;
		input_device_item_add(device,
                              [name UTF8String],
                              axisState,
                              ITEM_ID_XAXIS,
                              mouseAxisGetState);
        
        axis = [mouse xElement];
        name = @"Y-Axis";
        axisState =  &mouseState->y;
		input_device_item_add(device,
                              [name UTF8String],
                              axisState,
                              ITEM_ID_YAXIS,
                              mouseAxisGetState);
        
        int buttonCount = MIN([buttons count], MAX_BUTTONS);
        int i;
        for (i = 0; i < buttonCount; i++)
        {
            DDHidElement * button = [buttons objectAtIndex: i];
            
            NSString * name = format(@"Button %d", i+1);
            int * buttonState = &mouseState->buttons[i];
            input_device_item_add(device,
                                  [name UTF8String],
                                  buttonState,
                                  ITEM_ID_BUTTON1 + i,
                                  mouseButtonGetState);
        }
        
        mouseTag++;
    }
}

@end

@implementation MameInputController (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;
{
    uint32_t keyboardBit = 1 << [keyboard tag];
    uint32_t * keyState = &p->mKeyStates[usageId];
    *keyState |= keyboardBit;
}

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;
{
    uint32_t keyboardBit = 1 << [keyboard tag];
    uint32_t * keyState = &p->mKeyStates[usageId];
    *keyState &= ~keyboardBit;
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
             povNumber: (unsigned) povNumber
          valueChanged: (int) value;
{
    p->mJoystickStates[[joystick tag]].povs[povNumber] = value;
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
    int * axisState = &p->mMiceStates[[mouse tag]].x;
    *axisState += deltaX;
}

- (void) ddhidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
{
    int * axisState = &p->mMiceStates[[mouse tag]].y;
    *axisState += deltaY;
}

- (void) ddhidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
{
    int * buttonState = &p->mMiceStates[[mouse tag]].buttons[buttonNumber];
    *buttonState = 1;
}

- (void) ddhidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;
{
    int * buttonState = &p->mMiceStates[[mouse tag]].buttons[buttonNumber];
    *buttonState = 0;
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
