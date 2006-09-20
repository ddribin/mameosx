//
//  MameAudioController.h
//  mameosx
//
//  Created by Dave Dribin on 9/4/06.
//

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#include "osdepend.h"

@class MameController;
@class CircularBuffer;

@interface MameAudioController : NSObject
{
    MameController * mController;
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

- (id) initWithController: (MameController *) controller;

- (void) osd_init;

- (int) osd_start_audio_stream: (int) stereo;

- (int) osd_update_audio_stream: (INT16 *) buffer;

- (void) osd_stop_audio_stream;

- (void) osd_set_mastervolume: (int) attenuation;

- (int) osd_get_mastervolume;

- (void) osd_sound_enable: (int) enable;

@end
