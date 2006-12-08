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

#import "MameAudioController.h"
#import "MameController.h"
#import "MameConfiguration.h"
#import "VirtualRingBuffer.h"

#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>

#include "driver.h"

#define OSX_LOG_SOUND 0

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
    uint32_t bytesInBuffer;
    uint64_t underflows;
    uint64_t overflows;
    uint32_t mSamplesThisFrame;
} MameAudioStats;

#define NUM_STATS 10000
static MameAudioStats sAudioStats[NUM_STATS];
static uint32_t sAudioStatIndex = 0;

@interface MameAudioController (Private)

- (void) updateSampleAdjustment: (int) bytesInBuffer;

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

- (void) updateStats: (char) code
       bytesInBuffer: (uint32_t) bytesInBuffer;

- (void) dumpStats;

@end

@implementation MameAudioController

- (id) init;
{
    if ([super init] == nil)
        return nil;
    
    mEnabled = YES;
    mPaused = NO;
    mRingBuffer = nil;
    mOverflows = 0;
    mUnderflows = 0;
    
    NewAUGraph(&mGraph);
   
    return self;
}

//=========================================================== 
//  enabled 
//=========================================================== 
- (BOOL) enabled
{
    return mEnabled;
}

- (void) setEnabled: (BOOL) flag
{
    mEnabled = flag;
}

- (BOOL) paused;
{
    return mPaused;
}

- (void) setPaused: (BOOL) paused;
{
    mPaused = paused;
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
	
    err = AUGraphNewNode(mGraph, &desc, 0, NULL, &mOutputNode);
    
#if 0
    desc.componentType = kAudioUnitType_Effect;
    desc.componentSubType = 'Phas'; // kAudioUnitSubType_MatrixReverb;
	desc.componentManufacturer = 'ExSl'; // kAudioUnitManufacturer_Apple;
#elif 0
    desc.componentType = kAudioUnitType_Effect;
    desc.componentSubType = kAudioUnitSubType_NetSend;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
#elif 1
    desc.componentType = kAudioUnitType_Effect;
    desc.componentSubType = kAudioUnitSubType_MatrixReverb;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
#elif 1
    desc.componentType = kAudioUnitType_Effect;
    desc.componentSubType = kAudioUnitSubType_BandPassFilter;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
#endif
    err = AUGraphNewNode(mGraph, &desc, 0, NULL, &mEffectNode);

    desc.componentType = kAudioUnitType_FormatConverter;
    desc.componentSubType = kAudioUnitSubType_AUConverter;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    err = AUGraphNewNode(mGraph, &desc, 0, NULL, &mConverterNode);

    err = AUGraphConnectNodeInput (mGraph, mConverterNode, 0, mEffectNode, 0);
    err = AUGraphConnectNodeInput (mGraph, mEffectNode, 0, mOutputNode, 0);
	if (err) { NSLog(@"AUGraphConnectNodeInput=%ld\n", err); return; }

    err = AUGraphOpen(mGraph);
    err = AUGraphGetNodeInfo(mGraph, mOutputNode, NULL, NULL, NULL, &mOutputUnit);
    err = AUGraphGetNodeInfo(mGraph, mEffectNode, NULL, NULL, NULL, &mEffectUnit);
    err = AUGraphGetNodeInfo(mGraph, mConverterNode, NULL, NULL, NULL, &mConverterUnit);
   
	// Set up a callback function to generate output to the output unit
    AURenderCallbackStruct input;
	input.inputProc = MyRenderer;
	input.inputProcRefCon = self;
    
	err = AudioUnitSetProperty (mConverterUnit, 
								kAudioUnitProperty_SetRenderCallback, 
								kAudioUnitScope_Input,
								0, 
								&input, 
								sizeof(input));
	if (err) { NSLog(@"AudioUnitSetProperty-CB=%ld\n", err); return; }

    UInt32 bypass = 1;
	err = AudioUnitSetProperty (mEffectUnit, 
								kAudioUnitProperty_BypassEffect, 
								0,
								0, 
								&bypass, 
								sizeof(bypass));
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
    
    err = AudioUnitSetProperty (mConverterUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &streamFormat,
                                sizeof(AudioStreamBasicDescription));
	if (err) { NSLog(@"AudioUnitSetProperty-SF=%4.4s, %ld", (char*)&err, err); return 0; }
    
    mBytesPerFrame = streamFormat.mBytesPerFrame;
	
    // Initialize unit
    AUGraphUpdate (mGraph, NULL);

    err= AUGraphInitialize(mGraph);
    if (err) { NSLog(@"AUGraphInitialize=%ld", err); return 0; }
    
    // compute the buffer sizes
    mBufferSize = ((UINT64)MAX_BUFFER_SIZE * (UINT64)Machine->sample_rate) / 44100;
    mBufferSize = (mBufferSize * mBytesPerFrame) / 4;
    mBufferSize = (mBufferSize * 30) / Machine->screen[0].refresh;
    mBufferSize = (mBufferSize / 1024) * 1024;
    mBufferSize *= 1;
    
    mRingBuffer = [[VirtualRingBuffer alloc] initWithLength: mBufferSize];
    mBufferSize = [mRingBuffer bufferLength];
    mInitialBufferThresholdReached = NO;
    
#if 0
    int audio_latency = 1;
	// compute the upper/lower thresholds
	mLowWaterMarker = audio_latency * mBufferSize / 10;
	mHighWaterMarker = (audio_latency + 1) * mBufferSize / 10;
#else
	mLowWaterMarker = mBufferSize * 15/100;
	mHighWaterMarker = mBufferSize * 25/100;
#endif
    
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

    [mRingBuffer empty];
	// Start the rendering
	// The DefaultOutputUnit will do any format conversions to the format of the default device
    if (mEnabled)
    {
        err = AUGraphStart(mGraph);
        if (err) { NSLog(@"AUGraphStart=%ld", err); return 0; }
    }
    
    return mSamplesPerFrame;
}

- (int) osd_update_audio_stream: (INT16 *) buffer;
{
    if (Machine->sample_rate != 0 && mRingBuffer && !mPaused)
    {
        int inputBytes = mSamplesThisFrame * mBytesPerFrame;
        void * writePointer;
        UInt32 bytesAvailableToWrite =
            [mRingBuffer lengthAvailableToWriteReturningPointer: &writePointer];
        UInt32 bytesInBuffer = mBufferSize - bytesAvailableToWrite;
        [self updateSampleAdjustment: bytesInBuffer];
        UInt32 bytesToWrite = inputBytes;
        if (inputBytes > bytesAvailableToWrite)
        {
            bytesToWrite = bytesAvailableToWrite;
            mOverflows++;
        }
        if (bytesToWrite > 0)
        {
            memcpy(writePointer, buffer, bytesToWrite);
            [mRingBuffer didWriteLength: bytesToWrite];
        }

#if OSX_LOG_SOUND
        [self updateStats: 'W' bytesInBuffer: bytesInBuffer];
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
    err = AUGraphStop(mGraph);
    if (err) { NSLog(@"AUGraphStop=%ld\n", err); return; }
    err = AUGraphUninitialize(mGraph);
    if (err) { NSLog(@"AUGraphUninitialize=%ld\n", err); return; }
    
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

- (void) updateSampleAdjustment: (int) bytesInBuffer;
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
	if (bytesInBuffer < mLowWaterMarker)
	{
		// keep track of how many consecutive times we get this condition
		mConsecutiveLows++;
		mConsecutiveMids = 0;
		mConsecutiveHighs = 0;
        
		// adjust so that we generate more samples per frame to compensate
		mCurrentAdjustment = (mConsecutiveLows < MAX_SAMPLE_ADJUST) ? mConsecutiveLows : MAX_SAMPLE_ADJUST;
	}
    
	// do we have too many samples in the buffer?
	else if (bytesInBuffer > mHighWaterMarker)
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
    void * readPointer;
    UInt32 bytesAvailable =
        [mRingBuffer lengthAvailableToReadReturningPointer: &readPointer];
    UInt32 bytesInBuffer = bytesAvailable;
    if (mPaused)
    {
        bzero(ioData->mBuffers[0].mData,
              ioData->mBuffers[0].mDataByteSize);
        return noErr;
    }

    if (!mInitialBufferThresholdReached && (bytesInBuffer < mLowWaterMarker))
    {
        bzero(ioData->mBuffers[0].mData,
              ioData->mBuffers[0].mDataByteSize);
        return noErr;
    }
    mInitialBufferThresholdReached = YES;
    
    UInt32 bytesToRead;
    if (bytesAvailable > ioData->mBuffers[0].mDataByteSize)
    {
        bytesToRead = ioData->mBuffers[0].mDataByteSize;
    }
    else
    {
        bytesToRead = bytesAvailable;
        bzero(ioData->mBuffers[0].mData + bytesToRead,
              ioData->mBuffers[0].mDataByteSize - bytesToRead);
        mUnderflows++;
    }
    
    if (bytesToRead > 0)
    {
        // Finally read from the ring buffer.
        memcpy(ioData->mBuffers[0].mData, readPointer, bytesToRead);            
        [mRingBuffer didReadLength: bytesToRead];
    }
    
#if OSX_LOG_SOUND
    [self updateStats: 'R' bytesInBuffer: bytesInBuffer];
#endif
    
    return noErr;
}

- (void) updateStats: (char) code
       bytesInBuffer: (uint32_t) bytesInBuffer;
{
    @synchronized(self)
    {
        if (sAudioStatIndex >= NUM_STATS)
            return;
        MameAudioStats * stats = &sAudioStats[sAudioStatIndex];
        stats->timestamp = mach_absolute_time();
        stats->code = code;
        stats->bytesInBuffer = bytesInBuffer;
        stats->underflows = mUnderflows;
        stats->overflows = mOverflows;
        stats->mSamplesThisFrame = mSamplesThisFrame;
        sAudioStatIndex++;
    }
}

- (void) dumpStats;
{
    FILE * file = fopen("/tmp/audio_stats.txt", "w");
    uint32_t i;
    uint64_t start = 0;
    uint32_t capacity = mBufferSize;
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
        uint32_t percent = stats->bytesInBuffer * 100 / capacity;
        
        fprintf(file, "%5u %c %4qi.%06qi %5u/%u (%3u%%) %5qi %5qi %5u\n", i, stats->code,
                sec, msec,
                stats->bytesInBuffer, capacity, percent,
                stats->underflows, stats->overflows, stats->mSamplesThisFrame);
    }
    fclose(file);
}

@end
