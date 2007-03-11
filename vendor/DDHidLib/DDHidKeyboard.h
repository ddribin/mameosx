//
//  DDHidKeyboard.h
//  DDHidLib
//
//  Created by Dave Dribin on 3/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DDHidDevice.h"

@class DDHidElement;
@class DDHidQueue;

@interface DDHidKeyboard : DDHidDevice
{
    NSMutableArray * mKeyElements;
    
    id mDelegate;
}

+ (NSArray *) allKeyboards;

- (id) initWithDevice: (io_object_t) device error: (NSError **) error_;

#pragma mark -
#pragma mark Keyboards Elements

- (NSArray *) keyElements;

- (unsigned) numberOfKeys;

- (void) addElementsToQueue: (DDHidQueue *) queue;

#pragma mark -
#pragma mark Asynchronous Notification

- (void) setDelegate: (id) delegate;

- (void) addElementsToDefaultQueue;

@end

@interface NSObject (DDHidKeyboardDelegate)

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
               keyDown: (unsigned) usageId;

- (void) ddhidKeyboard: (DDHidKeyboard *) keyboard
                 keyUp: (unsigned) usageId;

@end
