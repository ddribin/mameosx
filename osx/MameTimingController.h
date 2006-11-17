/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>
#include "osdepend.h"

@class MameController;

@interface MameTimingController : NSObject
{
    MameController * mController;
    BOOL mThrottled;
    
    cycles_t mCyclesPerSecond;

    cycles_t mThrottleLastCycles;
    mame_time mThrottleRealtime;
    mame_time mThrottleEmutime;
}

- (void) osd_init;

- (cycles_t) osd_cycles;

- (cycles_t) osd_cycles_per_second;

- (cycles_t) osd_profiling_ticks;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (void) updateThrottle: (mame_time) emutime;

@end
