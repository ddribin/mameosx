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
#import "NXLog.h"

#define OSX_LOG_TIMING 0

#if OSX_LOG_TIMING
typedef struct
{
    char code;
    mame_time emutime;
    mame_time start_realtime;
    mame_time end_realtime;
    double game_speed_percent;
    double frames_per_second;
    int frame_skip_level;
    int frame_skip_counter;
    int frame_skip_adjust;
} MameTimingStats;

#define NUM_STATS 100000
static MameTimingStats sTimingStats[NUM_STATS];
static uint32_t sTimingStatsIndex = 0;

static void update_stats(char code, mame_time emutime, mame_time start_realtime,
                         mame_time end_realtime,
                         int frameSkipLevel, int frameSkipCounter,
                         int frameSkipAdjust);
static void dump_stats(void);

#endif

#define FRAMESKIP_LEVELS 12

// frameskipping tables
static const int sSkipTable[FRAMESKIP_LEVELS][FRAMESKIP_LEVELS] =
{
    { 0,0,0,0,0,0,0,0,0,0,0,0 },
    { 0,0,0,0,0,0,0,0,0,0,0,1 },
    { 0,0,0,0,0,1,0,0,0,0,0,1 },
    { 0,0,0,1,0,0,0,1,0,0,0,1 },
    { 0,0,1,0,0,1,0,0,1,0,0,1 },
    { 0,1,0,0,1,0,1,0,0,1,0,1 },
    { 0,1,0,1,0,1,0,1,0,1,0,1 },
    { 0,1,0,1,1,0,1,0,1,1,0,1 },
    { 0,1,1,0,1,1,0,1,1,0,1,1 },
    { 0,1,1,1,0,1,1,1,0,1,1,1 },
    { 0,1,1,1,1,1,0,1,1,1,1,1 },
    { 0,1,1,1,1,1,1,1,1,1,1,1 }
};

// For in-class use, so there is no Obj-C message passing overhead
static inline cycles_t osd_cycles_internal()
{
    return mach_absolute_time();
}

@implementation MameTimingController

- (void) osd_init;
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    mCyclesPerSecond = 1000000000LL *
        ((uint64_t)info.denom) / ((uint64_t)info.numer);
    NXLogDebug(@"cycles/second = %u/%u = %lld\n", info.denom, info.numer,
               mCyclesPerSecond);

    mThrottleLastCycles = 0;
    mFrameSkipCounter = 0;
    mFrameSkipLevel = 0;
}

- (cycles_t) osd_cycles;
{
    return osd_cycles_internal();
}

- (cycles_t) osd_cycles_per_second;
{
    return mCyclesPerSecond;
}

- (cycles_t) osd_profiling_ticks;
{
    return mach_absolute_time();
}

- (const char *) osd_get_fps_text: (const performance_info *) performance;
{
    static char buffer[1024];
    sprintf(buffer, "%s%2d%4d%%%4d/%d fps",
            "fskp", mFrameSkipLevel,
            (int)(performance->game_speed_percent + 0.5),
            (int)(performance->frames_per_second + 0.5),
            (int)(Machine->screen[0].refresh + 0.5));
    return buffer;
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
#if OSX_LOG_TIMING
    char code = 'U';
    mame_time start_realtime = mThrottleRealtime;
#endif

#if 0
    NSLog(@"emutime: %i, %qi", emutime.seconds, emutime.subseconds);
#endif
    int paused = mame_is_paused(Machine);
    if (paused)
    {
#if 0        
        mThrottleRealtime = mThrottleEmutime = sub_subseconds_from_mame_time(emutime, MAX_SUBSECONDS / PAUSED_REFRESH_RATE);
#else
#if OSX_LOG_TIMING
        code = 'P';
#endif
        goto resync;
#endif
    }
    
    // if time moved backwards (reset), or if it's been more than 1 second in emulated time, resync
    if (compare_mame_times(emutime, mThrottleEmutime) < 0 || sub_mame_times(emutime, mThrottleEmutime).seconds > 0)
    {
#if OSX_LOG_TIMING
        code = 'B';
#endif
        goto resync;
    }
    
    cycles_t cyclesPerSecond = mCyclesPerSecond;
    cycles_t diffCycles = osd_cycles_internal() - mThrottleLastCycles;
    mThrottleLastCycles += diffCycles;
    // NSLog(@"diff: %llu, last: %llu", diffCycles, mThrottleLastCycles);
    if (diffCycles > cyclesPerSecond)
    {
        NXLogDebug(@"More than 1 sec, diff: %qi, cps: %qi", diffCycles, cyclesPerSecond);
        // Resync
#if OSX_LOG_TIMING
        code = '1';
#endif
        goto resync;
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
#if OSX_LOG_TIMING
        code = 'S';
#endif
        goto resync;
    }
    
    mame_time timeTilTarget = sub_mame_times(mThrottleEmutime, mThrottleRealtime);
    cycles_t cyclesTilTarget = timeTilTarget.subseconds / subsecsPerCycle;
    cycles_t target = mThrottleLastCycles + cyclesTilTarget;
    
    cycles_t curr = osd_cycles_internal();
    uint64_t count = 0;
#if 1
    if (mThrottled)
    {
        mach_wait_until(mThrottleLastCycles + cyclesTilTarget*9/10);
        for (curr = osd_cycles_internal(); curr - target < 0; curr = osd_cycles_internal())
        {
            // NSLog(@"target: %qi, current %qi, diff: %qi", target, curr, curr - target);
            // Spin...
            count++;
        }
        // NSLog(@"Throttle count: %d", count);
    }
#endif
    
    // update realtime
    diffCycles = osd_cycles_internal() - mThrottleLastCycles;
    mThrottleLastCycles += diffCycles;
    mThrottleRealtime = add_subseconds_to_mame_time(mThrottleRealtime, diffCycles * subsecsPerCycle);
#if OSX_LOG_TIMING
    update_stats(code, emutime, start_realtime, mThrottleRealtime,
                 mFrameSkipLevel, mFrameSkipCounter, mFrameSkipAdjustment);
#endif
    
    return;
    
resync:
        mThrottleRealtime = mThrottleEmutime = emutime;
#if OSX_LOG_TIMING
        update_stats(code, emutime, start_realtime, mThrottleRealtime,
                     mFrameSkipLevel, mFrameSkipCounter, mFrameSkipAdjustment);
#endif
    return;
}

- (void) updateAutoFrameSkip;
{
    int frameSkipCounter = mFrameSkipCounter;
	mFrameSkipCounter = (mFrameSkipCounter + 1) % FRAMESKIP_LEVELS;

    // Only update at begining of sequence
    if (frameSkipCounter != 0)
        return;
    
	// skip if paused
	if (mame_is_paused(Machine))
		return;
    
	// don't adjust frameskip if we're paused or if the debugger was
	// visible this cycle or if we haven't run yet
	if (cpu_getcurrentframe() > 2 * FRAMESKIP_LEVELS)
	{
		const performance_info *performance = mame_get_performance_info();
        
		// if we're too fast, attempt to increase the frameskip
		if (performance->game_speed_percent >= 99.5)
		{
			mFrameSkipAdjustment++;
            
			// but only after 3 consecutive frames where we are too fast
			if (mFrameSkipAdjustment >= 3)
			{
				mFrameSkipAdjustment = 0;
				if (mFrameSkipLevel > 0)
                    mFrameSkipLevel--;
			}
		}
        
		// if we're too slow, attempt to increase the frameskip
		else
		{
			// if below 80% speed, be more aggressive
			if (performance->game_speed_percent < 80)
				mFrameSkipAdjustment -= (90 - performance->game_speed_percent) / 5;
            
			// if we're close, only force it up to frameskip 8
			else if (mFrameSkipLevel < 8)
				mFrameSkipAdjustment--;
            
			// perform the adjustment
			while (mFrameSkipAdjustment <= -2)
			{
				mFrameSkipAdjustment += 2;
				if (mFrameSkipLevel < FRAMESKIP_LEVELS - 1)
					mFrameSkipLevel++;
			}
		}
	}
}

- (int) skipFrame;
{
    return sSkipTable[mFrameSkipLevel][mFrameSkipCounter];
}

- (void) gameFinished;
{
#if OSX_LOG_TIMING
    dump_stats();
#endif
}

#if OSX_LOG_TIMING

static void update_stats(char code, mame_time emutime, mame_time start_realtime,
                         mame_time end_realtime,
                         int frameSkipLevel, int frameSkipCounter,
                         int frameSkipAdjust)
{
    if (sTimingStatsIndex >= NUM_STATS)
        return;
    
    const performance_info * performance = mame_get_performance_info();
    MameTimingStats * stats = &sTimingStats[sTimingStatsIndex];
    stats->code = code;
    stats->emutime = emutime;
    stats->start_realtime = start_realtime;
    stats->end_realtime = end_realtime;
    stats->game_speed_percent = performance->game_speed_percent;
    stats->frames_per_second = performance->frames_per_second;
    stats->frame_skip_level = frameSkipLevel;
    stats->frame_skip_counter = frameSkipCounter;
    stats->frame_skip_adjust = frameSkipAdjust;
    sTimingStatsIndex++;
}

static void dump_stats(void)
{
    FILE * file = fopen("/tmp/timing_stats.txt", "w");
    uint32_t i;
    for (i = 0; i < sTimingStatsIndex; i++)
    {
        MameTimingStats * stats = &sTimingStats[i];
        /* subseconds are tracked in attosecond (10^-18) increments */
        fprintf(file, "%5u %c %d.%018lld %d.%018lld %d.%018lld %5.1f%% %4.1f "
                "Skip: %2d, %2d = %d %d\n",
                i, stats->code,
                stats->emutime.seconds, stats->emutime.subseconds,
                stats->start_realtime.seconds, stats->start_realtime.subseconds,
                stats->end_realtime.seconds, stats->end_realtime.subseconds,
                stats->game_speed_percent, stats->frames_per_second,
                stats->frame_skip_level, stats->frame_skip_counter,
                sSkipTable[stats->frame_skip_level][stats->frame_skip_counter],
                stats->frame_skip_adjust);
    }
    fclose(file);
}

#endif

@end
