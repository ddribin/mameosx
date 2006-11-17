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

#import "MameTimingController.h"
#import "MameController.h"
#include <mach/mach_time.h>

@implementation MameTimingController

- (void) osd_init;
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    mCyclesPerSecond = 1000000000LL *
        ((uint64_t)info.denom) / ((uint64_t)info.numer);
    NSLog(@"cycles/second = %u/%u = %lld\n", info.denom, info.numer,
          mCyclesPerSecond);

    mThrottleLastCycles = 0;   
}

- (cycles_t) osd_cycles;
{
    return mach_absolute_time();
}

- (cycles_t) osd_cycles_per_second;
{
    return mCyclesPerSecond;
}

- (cycles_t) osd_profiling_ticks;
{
    return mach_absolute_time();
}

//=========================================================== 
//  throttled 
//=========================================================== 
- (BOOL) throttled
{
    return mThrottled;
}

- (void) setThrottled: (BOOL) flag
{
    mThrottled = flag;
}

// refresh rate while paused
#define PAUSED_REFRESH_RATE         30

- (void) updateThrottle: (mame_time) emutime;
{
#if 0
    NSLog(@"emutime: %i, %qi", emutime.seconds, emutime.subseconds);
#endif
    int paused = mame_is_paused(Machine);
    if (paused)
    {
#if 0        
        mThrottleRealtime = mThrottleEmutime = sub_subseconds_from_mame_time(emutime, MAX_SUBSECONDS / PAUSED_REFRESH_RATE);
#else
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
#endif
    }
    
    // if time moved backwards (reset), or if it's been more than 1 second in emulated time, resync
    if (compare_mame_times(emutime, mThrottleEmutime) < 0 || sub_mame_times(emutime, mThrottleEmutime).seconds > 0)
    {
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
    }
    
    cycles_t cyclesPerSecond = [self osd_cycles_per_second];
    cycles_t diffCycles = [self osd_cycles] - mThrottleLastCycles;
    mThrottleLastCycles += diffCycles;
    // NSLog(@"diff: %llu, last: %llu", diffCycles, mThrottleLastCycles);
    if (diffCycles > cyclesPerSecond)
    {
        NSLog(@"More than 1 sec, diff: %qi, cps: %qi", diffCycles, cyclesPerSecond);
        // Resync
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
    }
    
    subseconds_t subsecsPerCycle = MAX_SUBSECONDS / cyclesPerSecond;
#if 1
    // NSLog(@"max: %qi, sspc: %qi, add_subsecs: %qi, diff: %qi", MAX_SUBSECONDS, subsecsPerCycle, diffCycles * subsecsPerCycle, diffCycles);
    // NSLog(@"realtime: %i, %qi", mThrottleRealtime.seconds, mThrottleRealtime.subseconds);
#endif
    mThrottleRealtime = add_subseconds_to_mame_time(mThrottleRealtime, diffCycles * subsecsPerCycle);
    mThrottleEmutime = emutime;
    
    // if we're behind, just sync
    if (compare_mame_times(mThrottleEmutime, mThrottleRealtime) <= 0)
    {
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
    }
    
    mame_time timeTilTarget = sub_mame_times(mThrottleEmutime, mThrottleRealtime);
    cycles_t cyclesTilTarget = timeTilTarget.subseconds / subsecsPerCycle;
    cycles_t target = mThrottleLastCycles + cyclesTilTarget;
    
    cycles_t curr = [self osd_cycles];
    uint64_t count = 0;
#if 1
    if (mThrottled)
    {
        mach_wait_until(mThrottleLastCycles + cyclesTilTarget*9/10);
        for (curr = [self osd_cycles]; curr - target < 0; curr = [self osd_cycles])
        {
            // NSLog(@"target: %qi, current %qi, diff: %qi", target, curr, curr - target);
            // Spin...
            count++;
        }
        // NSLog(@"Throttle count: %d", count);
    }
#endif
    
    // update realtime
    diffCycles = [self osd_cycles] - mThrottleLastCycles;
    mThrottleLastCycles += diffCycles;
    mThrottleRealtime = add_subseconds_to_mame_time(mThrottleRealtime, diffCycles * subsecsPerCycle);
    
    return;
}

@end
