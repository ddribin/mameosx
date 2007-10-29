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
#import "MameKeyboard.h"
#import "MameMouse.h"
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

static NSMutableData * utf8Data(NSString * string);
static NSString * format(NSString * format, ...);


@interface MameInputControllerPrivate : NSObject
{
  @public
    NSMutableArray * mDeviceNames;
    NSMutableArray * mDevices;
    JoystickState mJoystickStates[MAX_JOYSTICKS];
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

- (void) addAllKeyboards;
- (void) addAllMice;

- (BOOL) addDevice: (DDHidDevice *) device tag: (int) tag;

- (void) initJoyCodes;

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

@implementation MameInputController

- (id) init
{
    if ([super init] == nil)
        return nil;
    
    p = [[MameInputControllerPrivate alloc] init];
    mEnabled = NO;
    mDevices = [[NSMutableArray alloc] init];
    
    return self;
}

- (void) dealloc
{
    [p release];
    [mDevices release];
    
    p = nil;
    mDevices = nil;
    
    [super dealloc];
}

- (void) osd_init;
{
    [p->mDevices removeAllObjects];
    [p->mDeviceNames removeAllObjects];

    [mDevices removeAllObjects];
    [self addAllKeyboards];
    [self addAllMice];

    [self initJoyCodes];
}

- (void) gameFinished;
{
    [mDevices makeObjectsPerformSelector: @selector(stopListening)];
    [mDevices removeAllObjects];

    [p->mDevices makeObjectsPerformSelector: @selector(stopListening)];
    [p->mDevices removeAllObjects];
    [p->mDeviceNames removeAllObjects];
}

// Todo: Fix keyboard enabled static hack
static BOOL sEnabled = NO;

- (BOOL) enabled;
{
    return mEnabled;
}

- (void) setEnabled: (BOOL) enabled;
{
    mEnabled = enabled;
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

- (void) addAllKeyboards;
{
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
                                                               mameTag: keyboardTag
                                                               enabled: &mEnabled];
        [keyboard autorelease];
        if (![keyboard tryStartListening])
        {
            JRLogInfo(@"Could not start listening to keyboard, skipping");
            continue;
        }

        [mDevices addObject: keyboard];
        [keyboard osd_init];
        keyboardTag++;
    }
}

- (void) addAllMice;
{
    int mouseTag = 0;
    NSArray * mice = [DDHidMouse allMice];
    int mouseCount = MIN([mice count], MAX_MICE);
    int mouseNumber;
    for (mouseNumber = 0; mouseNumber < mouseCount; mouseNumber++)
    {
        DDHidMouse * hidMouse = [mice objectAtIndex: mouseNumber];
        NSArray * buttons = [hidMouse buttonElements];
        JRLogInfo(@"Found mouse: %@ (%@), %d button(s)",
                  [hidMouse productName], [hidMouse manufacturer],
                  [buttons count]);
        MameMouse * mouse = [[MameMouse alloc] initWithDevice: hidMouse
                                                      mameTag: mouseTag
                                                      enabled: &mEnabled];
        [mouse autorelease];
        if (![mouse tryStartListening])
        {
            JRLogInfo(@"Could not start listening to mouse, skipping");
            continue;
        }
        
        [mDevices addObject: mouse];
        [mouse osd_init];
        mouseTag++;
    }
}

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
