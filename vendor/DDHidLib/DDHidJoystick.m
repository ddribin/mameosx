/*
 * Copyright (c) 2007 Dave Dribin
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

#import "DDHidLib.h"
#include <IOKit/hid/IOHIDUsageTables.h>

@interface DDHidJoystick (DDHidJoystickDelegate)

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

@interface DDHidJoystick (Private)

- (void) initJoystickElements: (NSArray *) elements;
- (void) addStick: (NSArray *) stickElements;
- (void) hidQueueHasEvents: (DDHidQueue *) hidQueue;

- (int) normalizeValue: (int) value
            forElement: (DDHidElement *) element;

- (BOOL) findStick: (unsigned *) stick
           element: (DDHidElement **) elementOut
   withXAxisCookie: (IOHIDElementCookie) cookie;
- (BOOL) findStick: (unsigned *) stick
           element: (DDHidElement **) elementOut
   withYAxisCookie: (IOHIDElementCookie) cookie;
- (BOOL) findOtherAxis: (unsigned *) otherAxis
                 stick: (unsigned *) stick
            withCookie: (IOHIDElementCookie) cookie;

@end

@implementation DDHidJoystick

+ (NSArray *) allJoysticks;
{
    NSArray * joysticks =
        [DDHidDevice allDevicesMatchingUsagePage: kHIDPage_GenericDesktop
                                         usageId: kHIDUsage_GD_Joystick
                                       withClass: self
                               skipZeroLocations: YES];
    NSArray * gamepads =
        [DDHidDevice allDevicesMatchingUsagePage: kHIDPage_GenericDesktop
                                         usageId: kHIDUsage_GD_GamePad
                                       withClass: self
                               skipZeroLocations: YES];

    NSMutableArray * allJoysticks = [NSMutableArray arrayWithArray: joysticks];
    [allJoysticks addObjectsFromArray: gamepads];
    [allJoysticks sortUsingSelector: @selector(compareByLocationId:)];
    return allJoysticks;
}

- (id) initWithDevice: (io_object_t) device error: (NSError **) error_;
{
    self = [super initWithDevice: device error: error_];
    if (self == nil)
        return nil;
    
    mButtonElements = [[NSMutableArray alloc] init];
    mSticks = [[NSMutableArray alloc] init];
    [self initJoystickElements: [self elements]];
    mDelegate = nil;
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mSticks release];
    [mButtonElements release];
    
    mSticks = nil;
    mButtonElements = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark Joystick Elements

//=========================================================== 
// - buttonElements
//=========================================================== 
- (NSArray *) buttonElements;
{
    return mButtonElements; 
}

- (unsigned) numberOfButtons;
{
    return [mButtonElements count];
}

#pragma mark -
#pragma mark Sticks - indexed accessors

- (unsigned int) countOfSticks 
{
    return [mSticks count];
}

- (DDHidJoystickStick *) objectInSticksAtIndex: (unsigned int)index 
{
    return [mSticks objectAtIndex: index];
}

- (void) addElementsToQueue: (DDHidQueue *) queue;
{
    NSEnumerator * e = [mSticks objectEnumerator];
    DDHidJoystickStick * stick;
    while (stick = [e nextObject])
    {
        [queue addElements: [stick allElements]];
    }
    
    [queue addElements: mButtonElements];
}


#pragma mark -
#pragma mark Asynchronous Notification

- (void) setDelegate: (id) delegate;
{
    mDelegate = delegate;
}

- (void) addElementsToDefaultQueue;
{
    [self addElementsToQueue: mDefaultQueue];
}

@end

@implementation DDHidJoystick (Private)

- (void) initJoystickElements: (NSArray *) elements;
{
    NSEnumerator * e = [elements objectEnumerator];
    DDHidElement * element;
    DDHidJoystickStick * currentStick = [[[DDHidJoystickStick alloc] init] autorelease];
    BOOL stickHasElements = NO;

    while (element = [e nextObject])
    {
        unsigned usagePage = [[element usage] usagePage];
        unsigned usageId = [[element usage] usageId];
        NSArray * subElements = [element elements];
        
        if ([subElements count] > 0)
        {
            [self initJoystickElements: subElements];
        }
        else if ((usagePage == kHIDPage_GenericDesktop) &&
            (usageId == kHIDUsage_GD_Pointer))
        {
            [self addStick: subElements];
        }
        else if ([currentStick addElement: element])
        {
            stickHasElements = YES;
        }
        else if ((usagePage == kHIDPage_Button) &&
                 (usageId > 0))
        {
            [mButtonElements addObject: element];
        }
    }
    if (stickHasElements)
    {
        [mSticks addObject: currentStick];
    }
}

- (void) addStick: (NSArray *) elements;
{
    NSEnumerator * e = [elements objectEnumerator];
    DDHidElement * element;
    while (element = [e nextObject])
    {
        NSLog(@"Stick element: %@", [[element usage] usageName]);
    }
}

- (void) hidQueueHasEvents: (DDHidQueue *) hidQueue;
{
    DDHidEvent * event;
    while (event = [hidQueue nextEvent])
    {
        IOHIDElementCookie cookie = [event elementCookie];
        SInt32 value = [event value];
        DDHidElement * element;
        unsigned stick;
        // unsigned otherAxis;
        if ([self findStick: &stick element: &element withXAxisCookie: cookie])
        {
            int normalizedValue = [self normalizeValue: value forElement: element];
            [self hidJoystick: self stick: stick xChanged: normalizedValue];
        }
        else if ([self findStick: &stick element: &element withYAxisCookie: cookie])
        {
            int normalizedValue = [self normalizeValue: value forElement: element];
            [self hidJoystick: self stick: stick yChanged: normalizedValue];
        }
#if 0
        else if (cookie == [[self wheelElement] cookie])
        {
            if ((value != 0) &&
                [mDelegate respondsToSelector: @selector(hidMouse:wheelChanged:)])
            {
                [mDelegate hidMouse: self wheelChanged: value];
            }
        }
#endif
        else
        {
            unsigned i = 0;
            for (i = 0; i < [[self buttonElements] count]; i++)
            {
                if (cookie == [[[self buttonElements] objectAtIndex: i] cookie])
                    break;
            }
            
            if (value == 1)
            {
                [self hidJoystick: self buttonDown: i];
            }
            else if (value == 0)
            {
                [self hidJoystick: self buttonUp: i];
            }
            else
            {
                DDHidElement * element = [self elementForCookie: [event elementCookie]];
                NSLog(@"Element: %@, value: %d", [[element usage] usageName], [event value]);
            }
        }
    }
}

- (int) normalizeValue: (int) value
            forElement: (DDHidElement *) element;
{
    int normalizedUnits = DDHID_JOYSTICK_VALUE_MAX - DDHID_JOYSTICK_VALUE_MIN;
    int elementUnits = [element maxValue] - [element minValue];
    
    int normalizedValue = (((value - [element minValue]) * normalizedUnits) /
                           elementUnits) + DDHID_JOYSTICK_VALUE_MIN;
    return normalizedValue;
}

- (BOOL) findStick: (unsigned *) stick
           element: (DDHidElement **) elementOut
   withXAxisCookie: (IOHIDElementCookie) cookie;
{
    unsigned i;
    for (i = 0; i < [mSticks count]; i++)
    {
        DDHidElement * element = [[mSticks objectAtIndex: i] xAxisElement];
        if ((element != nil) && ([element cookie] == cookie))
        {
            *stick = i;
            *elementOut = element;
            return YES;
        }
    }
    return NO;
}

- (BOOL) findStick: (unsigned *) stick
           element: (DDHidElement **) elementOut
   withYAxisCookie: (IOHIDElementCookie) cookie;
{
    unsigned i;
    for (i = 0; i < [mSticks count]; i++)
    {
        DDHidElement * element = [[mSticks objectAtIndex: i] yAxisElement];
        if ((element != nil) && ([element cookie] == cookie))
        {
            *stick = i;
            *elementOut = element;
            return YES;
        }
    }
    return NO;
}

- (BOOL) findOtherAxis: (unsigned *) otherAxis
                 stick: (unsigned *) stick
            withCookie: (IOHIDElementCookie) cookie;
{
    return NO;
}

@end

@implementation DDHidJoystick (DDHidJoystickDelegate)

- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            xChanged: (int) value;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate hidJoystick: joystick stick: stick xChanged: value];
}

- (void) hidJoystick: (DDHidJoystick *)  joystick
               stick: (unsigned) stick
            yChanged: (int) value;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate hidJoystick: joystick stick: stick yChanged: value];
}

- (void) hidJoystick: (DDHidJoystick *) joystick
          buttonDown: (unsigned) buttonNumber;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate hidJoystick: joystick buttonDown: buttonNumber];
}

- (void) hidJoystick: (DDHidJoystick *) joystick
            buttonUp: (unsigned) buttonNumber;  
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate hidJoystick: joystick buttonUp: buttonNumber];
}

@end

@implementation DDHidJoystickStick

- (id) init
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mStickElements = [[NSMutableArray alloc] init];
    mXAxisElement = nil;
    mYAxisElement = nil;
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mStickElements release];
    [mXAxisElement release];
    [mYAxisElement release];
    
    mStickElements = nil;
    mXAxisElement = nil;
    mYAxisElement = nil;
    [super dealloc];
}

-  (BOOL) addElement: (DDHidElement *) element;
{
    DDHidUsage * usage = [element usage];
    if ([usage usagePage] != kHIDPage_GenericDesktop)
        return NO;
    
    BOOL elementAdded = YES;
    switch ([usage usageId])
    {
        case kHIDUsage_GD_X:
            if (mXAxisElement == nil)
                mXAxisElement = [element retain];
            else
                [mStickElements addObject: element];
            break;
            
        case kHIDUsage_GD_Y:
            if (mYAxisElement == nil)
                mYAxisElement = [element retain];
            else
                [mStickElements addObject: element];
            break;
            
        case kHIDUsage_GD_Z:
            [mStickElements addObject: element];
            break;
            
        default:
            elementAdded = NO;
            
    }
    
    return elementAdded;
#if 0
    
    BOOL isXAxis = [usage isEqualToUsagePage: kHIDPage_GenericDesktop
                                     usageId: kHIDUsage_GD_X];
    BOOL isYAxis = [usage isEqualToUsagePage: kHIDPage_GenericDesktop
                                     usageId: kHIDUsage_GD_Y];
    if (isXAxis && (mXAxisElement == nil))
        mXAxisElement = [element retain];
    else if (isYAxis && (mYAxisElement == nil))
        mYAxisElement = [element retain];
    else
        [mStickElements addObject: element];
#endif
}

- (NSArray *) allElements;
{
    NSMutableArray * elements = [NSMutableArray array];
    if (mXAxisElement != nil)
        [elements addObject: mXAxisElement];
    if (mYAxisElement != nil)
        [elements addObject: mYAxisElement];
    [elements addObjectsFromArray: mStickElements];
    return elements;
}

#pragma mark -
#pragma mark mStickElements - indexed accessors

- (unsigned int) countOfStickElements 
{
    return [mStickElements count];
}

- (DDHidElement *) objectInStickElementsAtIndex: (unsigned int)index 
{
    return [mStickElements objectAtIndex: index];
}

- (DDHidElement *) xAxisElement;
{
    return mXAxisElement;
}

- (DDHidElement *) yAxisElement;
{
    return mYAxisElement;
}

- (NSString *) description;
{
    return [mStickElements description];
}

@end
