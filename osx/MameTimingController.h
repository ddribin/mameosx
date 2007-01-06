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

@interface MameTimingController : NSObject
{
    BOOL mThrottled;
    
    cycles_t mCyclesPerSecond;

    cycles_t mThrottleLastCycles;
    mame_time mThrottleRealtime;
    mame_time mThrottleEmutime;
    
    int mFrameSkipCounter;
    int mFrameSkipLevel;
    int mFrameSkipAdjustment;

    uint64_t mFramesDisplayed;
    uint64_t mFramesRendered;
    cycles_t mFrameStartTime;
    cycles_t mFrameEndTime;
}

- (void) osd_init;

- (cycles_t) osd_cycles;

- (cycles_t) osd_cycles_per_second;

- (cycles_t) osd_profiling_ticks;

- (const char *) osd_get_fps_text: (const performance_info *) performance;

- (int) osd_update: (mame_time) emutime;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (void) updateThrottle: (mame_time) emutime;

- (void) updateAutoFrameSkip;

- (int) skipFrame;

- (void) gameFinished;

- (cycles_t) fpsCycles;

- (uint64_t) framesDisplayed;

- (uint64_t) framesRendered;

- (void) frameWasDisplayed;

- (void) frameWasRendered;

- (double) fpsDisplayed;

- (double) fpsRendered;

@end
