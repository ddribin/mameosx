//
//  DDHidKeyboard.m
//  DDHidLib
//
//  Created by Dave Dribin on 3/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "DDHidKeyboard.h"
#import "DDHidElement.h"
#import "DDHidUsage.h"
#import "DDHidQueue.h"
#import "DDHidEvent.h"
#include <IOKit/hid/IOHIDUsageTables.h>

@interface DDHidKeyboard (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;

@end

@interface DDHidKeyboard (Private)

- (void) initKeyboardElements: (NSArray *) elements;
- (void) hidQueueHasEvents: (DDHidQueue *) hidQueue;

@end

@implementation DDHidKeyboard

+ (NSArray *) allKeyboards;
{
    return
        [DDHidDevice allDevicesMatchingUsagePage: kHIDPage_GenericDesktop
                                         usageId: kHIDUsage_GD_Keyboard
                                       withClass: self
                               skipZeroLocations: YES];
}

- (id) initWithDevice: (io_object_t) device error: (NSError **) error_;
{
    self = [super initWithDevice: device error: error_];
    if (self == nil)
        return nil;
    
    mKeyElements = [[NSMutableArray alloc] init];
    [self initKeyboardElements: [self elements]];
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mKeyElements release];
    
    mKeyElements = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark Keyboards Elements

- (NSArray *) keyElements;
{
    return mKeyElements;
}

- (unsigned) numberOfKeys;
{
    return [mKeyElements count];
}

- (void) addElementsToQueue: (DDHidQueue *) queue;
{
    [queue addElements: mKeyElements];
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

@implementation DDHidKeyboard (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidKeyboard: keyboard keyDown: usageId];
}

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidKeyboard: keyboard keyUp: usageId];
}

@end

@implementation DDHidKeyboard (Private)

- (void) initKeyboardElements: (NSArray *) elements;
{
    NSEnumerator * e = [elements objectEnumerator];
    DDHidElement * element;
    while (element = [e nextObject])
    {
        unsigned usagePage = [[element usage] usagePage];
        unsigned usageId = [[element usage] usageId];
        if (usagePage == kHIDPage_KeyboardOrKeypad)
        {
            if ((usageId >= 0x04) && (usageId <= 0xA4) ||
                (usageId >= 0xE0) && (usageId <= 0xE7))
            {
                [mKeyElements addObject: element];
            }
        }
        NSArray * subElements = [element elements];
        if (subElements != nil)
            [self initKeyboardElements: subElements];
    }
}

- (void) hidQueueHasEvents: (DDHidQueue *) hidQueue;
{
    DDHidEvent * event;
    while (event = [hidQueue nextEvent])
    {
        DDHidElement * element = [self elementForCookie: [event elementCookie]];
        unsigned usageId = [[element usage] usageId];
        SInt32 value = [event value];
        if (value == 1)
            [self ddhidKeyboard: self keyDown: usageId];
        else
            [self ddhidKeyboard: self keyUp: usageId];
    }
}

@end
