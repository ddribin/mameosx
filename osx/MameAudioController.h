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
@class VirtualRingBuffer;
@class NXAudioUnit;
@class NXAudioUnitGraph;
@class NXAudioUnitNode;

@interface MameAudioController : NSObject
{
    BOOL mEnabled;
    BOOL mPaused;
    int mAttenuation;

    NXAudioUnitGraph * mGraph;

    NXAudioUnitNode * mConverterNode;
    NXAudioUnitNode * mEffectNode;
    NXAudioUnitNode * mOutputNode;

    NXAudioUnit * mConverterUnit;
    NXAudioUnit * mEffectUnit;

    size_t mBufferSize;
    VirtualRingBuffer * mRingBuffer;
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

- (BOOL) paused;
- (void) setPaused: (BOOL) paused;

- (BOOL) effectEnabled;
- (void) setEffectEnabled: (BOOL) effectEnabled;

- (void) osd_init;

- (int) osd_start_audio_stream: (int) stereo;

- (int) osd_update_audio_stream: (INT16 *) buffer;

- (void) osd_stop_audio_stream;

- (void) osd_set_mastervolume: (int) attenuation;

- (int) osd_get_mastervolume;

- (void) osd_sound_enable: (int) enable;

@end
