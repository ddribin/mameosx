//
//  MameInputController.h
//  mameosx
//
//  Created by Dave Dribin on 9/4/06.
//

#import <Cocoa/Cocoa.h>
#include "osdepend.h"


@interface MameInputController : NSObject
{
    INT32 * mKeyStates;
}

- (void) osd_init;

- (const os_code_info *) osd_get_code_list;
- (INT32) osd_get_code_value: (os_code) code;

- (void) handleKeyDown: (NSEvent *) event;
- (void) handleKeyUp: (NSEvent *) event;
- (void) flagsChanged: (NSEvent *) event;


@end
