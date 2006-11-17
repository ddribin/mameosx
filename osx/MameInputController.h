/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>
#include "osdepend.h"


@interface MameInputController : NSObject
{
    INT32 * mKeyStates;
}

- (void) osd_init;

- (const os_code_info *) osd_get_code_list;
- (INT32) osd_get_code_value: (os_code) code;

- (void) keyDown: (NSEvent *) event;
- (void) keyUp: (NSEvent *) event;
- (void) flagsChanged: (NSEvent *) event;


@end
