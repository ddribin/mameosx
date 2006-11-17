/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#include "osdepend.h"

@class MameController;
@class CircularBuffer;

@interface MameAudioController : NSObject
{
    BOOL mEnabled;
    int mAttenuation;
    AudioUnit mOutputUnit;
    CircularBuffer * mBuffer;
    BOOL mInitialBufferThresholdReached;

    unsigned mBytesPerFrame;

    double mSamplesPerFrame;
    double mSamplesLeftOver;
    UINT32 mSamplesThisFrame;

    int mCurrentAdjustment;
    int mLowWaterMarker;
	int mHighWaterMarker;

	int mConsecutiveLows;
	int mConsecutiveMids;
	int mConsecutiveHighs;

    uint64_t mOverflows;
    uint64_t mUnderflows;
}

- (id) init;

- (BOOL) enabled;
- (void) setEnabled: (BOOL) flag;

- (void) osd_init;

- (int) osd_start_audio_stream: (int) stereo;

- (int) osd_update_audio_stream: (INT16 *) buffer;

- (void) osd_stop_audio_stream;

- (void) osd_set_mastervolume: (int) attenuation;

- (int) osd_get_mastervolume;

- (void) osd_sound_enable: (int) enable;

@end
