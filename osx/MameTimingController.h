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
