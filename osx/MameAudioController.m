//
//  MameAudioController.m
//  mameosx
//
//  Created by Dave Dribin on 9/4/06.
//

#import "MameAudioController.h"
#import "MameConfiguration.h"
#import "CircularBuffer.h"

#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>

#include "driver.h"

// #define OSX_LOG_SOUND 1

// the local buffer is what the stream buffer feeds from
// note that this needs to be large enough to buffer at frameskip 11
// for 30fps games like Tapper; we will scale the value down based
// on the actual framerate of the game
static const int MAX_BUFFER_SIZE = (128 * 1024);

// this is the maximum number of extra samples we will ask for
// per frame (I know this looks like a lot, but most of the
// time it will generally be nowhere close to this)
static const int MAX_SAMPLE_ADJUST = 32;

typedef struct
{
    uint64_t timestamp;
    char code;
    uint32_t bufferSize;
    uint64_t underflows;
    uint64_t overflows;
    uint32_t mSamplesThisFrame;
} MameAudioStats;

#define NUM_STATS 10000
static MameAudioStats sAudioStats[NUM_STATS];
static uint32_t sAudioStatIndex = 0;

@interface MameAudioController (Private)

OSStatus static MyRenderer(void	* inRefCon,
                           AudioUnitRenderActionFlags * ioActionFlags,
                           const AudioTimeStamp * inTimeStamp,
                           UInt32 inBusNumber,
                           UInt32 inNumberFrames,
                           AudioBufferList * ioData);

- (OSStatus) render: (AudioUnitRenderActionFlags *) ioActionFlags
          timeStamp: (const AudioTimeStamp *) inTimeStamp
          busNumber: (UInt32) inBusNumber
       numberFrames: (UInt32) inNumberFrames
         bufferList: (AudioBufferList *) ioData;

- (void) updateStats: (char) code;

- (void) dumpStats;

@end

@implementation MameAudioController

- (id) init
{
    if ([super init] == nil)
        return nil;
    
    mBuffer = nil;
    mOverflows = 0;
    mUnderflows = 0;
   
    return self;
}

- (void) osd_init;
{
	OSStatus err = noErr;
    
	// Open the default output unit
	ComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_DefaultOutput;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	
	Component comp = FindNextComponent(NULL, &desc);
	if (comp == NULL) { NSLog(@"FindNextComponent\n"); return; }
	
	err = OpenAComponent(comp, &mOutputUnit);
	if (comp == NULL) { NSLog(@"OpenAComponent=%ld\n", err); return; }
    
	// Set up a callback function to generate output to the output unit
    AURenderCallbackStruct input;
	input.inputProc = MyRenderer;
	input.inputProcRefCon = self;
    
	err = AudioUnitSetProperty (mOutputUnit, 
								kAudioUnitProperty_SetRenderCallback, 
								kAudioUnitScope_Input,
								0, 
								&input, 
								sizeof(input));
	if (err) { NSLog(@"AudioUnitSetProperty-CB=%ld\n", err); return; }
}

- (int) osd_start_audio_stream: (int) stereo;
{
    int channels = stereo ? 2 : 1;
	OSStatus err = noErr;
    
    UInt32 formatFlags = 0
		| kLinearPCMFormatFlagIsPacked
        | kLinearPCMFormatFlagIsSignedInteger 
#if __BIG_ENDIAN__
        | kLinearPCMFormatFlagIsBigEndian
#endif
        ;

	// We tell the Output Unit what format we're going to supply data to it
	// this is necessary if you're providing data through an input callback
	// AND you want the DefaultOutputUnit to do any format conversions
	// necessary from your format to the device's format.
	AudioStreamBasicDescription streamFormat;
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mSampleRate = Machine->sample_rate;
    streamFormat.mChannelsPerFrame = channels;
    streamFormat.mFormatFlags = formatFlags;

    streamFormat.mBitsPerChannel = 16;	
    streamFormat.mFramesPerPacket = 1;	
    streamFormat.mBytesPerFrame = streamFormat.mBitsPerChannel * streamFormat.mChannelsPerFrame / 8;
    streamFormat.mBytesPerPacket = streamFormat.mBytesPerFrame * streamFormat.mFramesPerPacket;
    
    err = AudioUnitSetProperty (mOutputUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &streamFormat,
                                sizeof(AudioStreamBasicDescription));
	if (err) { NSLog(@"AudioUnitSetProperty-SF=%4.4s, %ld", (char*)&err, err); return; }
    
    mBytesPerFrame = streamFormat.mBytesPerFrame;
	
    // Initialize unit
	err = AudioUnitInitialize(mOutputUnit);
	if (err) { NSLog(@"AudioUnitInitialize=%ld", err); return; }
    
    unsigned stream_buffer_size;
    // compute the buffer sizes
    stream_buffer_size = ((UINT64)MAX_BUFFER_SIZE * (UINT64)Machine->sample_rate) / 44100;
    stream_buffer_size = (stream_buffer_size * mBytesPerFrame) / 4;
    stream_buffer_size = (stream_buffer_size * 30) / Machine->screen[0].refresh;
    stream_buffer_size = (stream_buffer_size / 1024) * 1024;
    stream_buffer_size *= 1;
    
    mBuffer = [[CircularBuffer alloc] initWithCapacity: stream_buffer_size];
    mInitialBufferThresholdReached = NO;
    
    int audio_latency = 1;
	// compute the upper/lower thresholds
	mLowWaterMarker = audio_latency * stream_buffer_size / 5;
	mHighWaterMarker = (audio_latency + 1) * stream_buffer_size / 5;
    
    mConsecutiveLows = 0;
	mConsecutiveMids = 0;
	mConsecutiveHighs = 0;

    // determine the number of samples per frame
    mSamplesPerFrame = (double)Machine->sample_rate / (double)Machine->screen[0].refresh;

    // compute how many samples to generate the first frame
    mSamplesLeftOver = mSamplesPerFrame;
    mSamplesThisFrame = (UINT32)mSamplesLeftOver;
    mSamplesLeftOver -= (double)mSamplesThisFrame;
    
    mCurrentAdjustment = 0;
    
	// Start the rendering
	// The DefaultOutputUnit will do any format conversions to the format of the default device
    if ([[MameConfiguration globalConfiguration] soundEnabled])
    {
        err = AudioOutputUnitStart (mOutputUnit);
        if (err) { NSLog(@"AudioOutputUnitStart=%ld", err); return; }
    }
    
    return mSamplesPerFrame;
}

- (void) update_sample_adjustment: (int) buffered
{
	// if we're not throttled don't bother
#if 0
	if (!video_config.throttle)
	{
		mConsecutiveLows = 0;
		mConsecutiveMids = 0;
		mConsecutiveHighs = 0;
		mCurrentAdjustment = 0;
		return;
	}
#endif
    
	// do we have too few samples in the buffer?
	if (buffered < mLowWaterMarker)
	{
		// keep track of how many consecutive times we get this condition
		mConsecutiveLows++;
		mConsecutiveMids = 0;
		mConsecutiveHighs = 0;
        
		// adjust so that we generate more samples per frame to compensate
		mCurrentAdjustment = (mConsecutiveLows < MAX_SAMPLE_ADJUST) ? mConsecutiveLows : MAX_SAMPLE_ADJUST;
	}
    
	// do we have too many samples in the buffer?
	else if (buffered > mHighWaterMarker)
	{
		// keep track of how many consecutive times we get this condition
		mConsecutiveLows = 0;
		mConsecutiveMids = 0;
		mConsecutiveHighs++;
        
		// adjust so that we generate more samples per frame to compensate
		mCurrentAdjustment = (mConsecutiveHighs < MAX_SAMPLE_ADJUST) ? -mConsecutiveHighs : -MAX_SAMPLE_ADJUST;
	}
    
	// otherwise, we're in the sweet spot
	else
	{
		// keep track of how many consecutive times we get this condition
		mConsecutiveLows = 0;
		mConsecutiveMids++;
		mConsecutiveHighs = 0;
        
		// after 10 or so of these, revert back to no adjustment
		if (mConsecutiveMids > 10 && mCurrentAdjustment != 0)
		{
			mCurrentAdjustment = 0;
		}
	}
}

- (int) osd_update_audio_stream: (INT16 *) buffer;
{
    if (Machine->sample_rate != 0 && mBuffer)
    {
        [self update_sample_adjustment: [mBuffer size]];
        int input_bytes = mSamplesThisFrame * mBytesPerFrame;
        
        unsigned bytesWritten = [mBuffer writeBytes: buffer length: input_bytes];
        if (bytesWritten < input_bytes)
            mOverflows++;

#if OSX_LOG_SOUND
        [self updateStats: 'W'];
#endif
    }
    
    // compute how many samples to generate next frame
    mSamplesLeftOver += mSamplesPerFrame;
    mSamplesThisFrame = (UINT32)mSamplesLeftOver;
    mSamplesLeftOver -= (double)mSamplesThisFrame;
    
    mSamplesThisFrame += mCurrentAdjustment;
    
    // return the samples to play this next frame
    return mSamplesThisFrame;
}

- (void) osd_stop_audio_stream;
{
	OSStatus err = noErr;
    err = AudioUnitUninitialize (mOutputUnit);
	if (err) { printf ("AudioUnitUninitialize=%ld\n", err); return; }
#if OSX_LOG_SOUND
    NSLog(@"Overflows: %qi, underflows: %qi", mOverflows, mUnderflows);
    [self dumpStats];
#endif
}

- (void) osd_set_mastervolume: (int) attenuation;
{
    mAttenuation = attenuation;
}

- (int) osd_get_mastervolume;
{
    return mAttenuation;
}

- (void) osd_sound_enable: (int) enable;
{
}

@end

@implementation MameAudioController (Private)

OSStatus static MyRenderer(void	* inRefCon,
                           AudioUnitRenderActionFlags * ioActionFlags,
                           const AudioTimeStamp * inTimeStamp,
                           UInt32 inBusNumber,
                           UInt32 inNumberFrames,
                           AudioBufferList * ioData)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    MameAudioController * controller = (MameAudioController *) inRefCon;
    OSStatus rc = [controller render: ioActionFlags
                           timeStamp: inTimeStamp
                           busNumber: inBusNumber
                        numberFrames: inNumberFrames
                          bufferList: ioData];
    [pool release];
    return rc;
}

- (OSStatus) render: (AudioUnitRenderActionFlags *) ioActionFlags
          timeStamp: (const AudioTimeStamp *) inTimeStamp
          busNumber: (UInt32) inBusNumber
       numberFrames: (UInt32) inNumberFrames
         bufferList: (AudioBufferList *) ioData;
{
    memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
    if (mame_is_paused())
        return noErr;
    if (!mInitialBufferThresholdReached && ([mBuffer size] < mLowWaterMarker))
    {
        return noErr;
    }
    mInitialBufferThresholdReached = YES;
    
    unsigned bytesRead = [mBuffer readBytes: ioData->mBuffers[0].mData
                                     length: ioData->mBuffers[0].mDataByteSize];
    
    if (bytesRead != ioData->mBuffers[0].mDataByteSize)
    {
        mUnderflows++;
    }
    
#if OSX_LOG_SOUND
    [self updateStats: 'R'];
#endif
    
    return noErr;
}

- (void) updateStats: (char) code;
{
    @synchronized(self)
    {
        if (sAudioStatIndex >= NUM_STATS)
            return;
        MameAudioStats * stats = &sAudioStats[sAudioStatIndex];
        stats->timestamp = mach_absolute_time();
        stats->code = code;
        stats->bufferSize = [mBuffer size];
        stats->underflows = mUnderflows;
        stats->overflows = mOverflows;
        stats->mSamplesThisFrame = mSamplesThisFrame;
        sAudioStatIndex++;
    }
}

- (void) dumpStats;
{
    FILE * file = fopen("audio_stats.txt", "w");
    uint32_t i;
    uint64_t start = 0;
    uint32_t capacity = [mBuffer capacity];
    for (i = 0; i < sAudioStatIndex; i++)
    {
        MameAudioStats * stats = &sAudioStats[i];
        
        Nanoseconds nanoS = AbsoluteToNanoseconds( *(AbsoluteTime *) &stats->timestamp );
        uint64_t nano = *(uint64_t *) &nanoS;
        
        if (start == 0)
            start = nano;
        
        uint64_t diff = (nano - start) / 1000;
        uint64_t sec = diff / 1000000;
        uint64_t msec = diff % 1000000;
        uint32_t percent = stats->bufferSize * 100 / capacity;
        
        fprintf(file, "%5u %c %4qi.%06qi %5u/%u (%3u%%) %5qi %5qi %5u\n", i, stats->code,
                sec, msec,
                stats->bufferSize, capacity, percent,
                stats->underflows, stats->overflows, stats->mSamplesThisFrame);
    }
    fclose(file);
}

@end
