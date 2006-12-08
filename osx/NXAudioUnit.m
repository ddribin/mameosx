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

#import "NXAudioUnit.h"
#import "NXAudioException.h"

#define THROW_IF NXThrowAudioIfErr

@implementation NXAudioUnit

- (id) initWithAudioUnit: (AudioUnit) audioUnit;
{
    self = [super init];
    if (self == nil)
        return nil;

    mAudioUnit = audioUnit;
    
    return self;
}

- (AudioUnit) AudioUnit;
{
    return mAudioUnit;
}


- (void) setRenderCallback: (AURenderCallback) callback
                   context: (void *) context;
{
    AURenderCallbackStruct input;
	input.inputProc = callback;
	input.inputProcRefCon = context;
    THROW_IF(AudioUnitSetProperty([self AudioUnit],
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  0,
                                  &input, sizeof(input)));
}

- (void) setBypass: (BOOL) bypass;
{
    UInt32 bypassInt = bypass? 1 : 0;
    THROW_IF(AudioUnitSetProperty([self AudioUnit],
                                  kAudioUnitProperty_BypassEffect, 
                                  0,
                                  0, 
                                  &bypassInt, 
                                  sizeof(bypassInt)));
}


- (BOOL) bypass;
{
    UInt32 bypassInt;
    UInt32 size = sizeof(bypassInt);
    THROW_IF(AudioUnitGetProperty([self AudioUnit],
                                  kAudioUnitProperty_BypassEffect, 
                                  0,
                                  0, 
                                  &bypassInt, &size));
    return (bypassInt == 0)? NO : YES;
}

- (void) setStreamFormatWithDescription:
    (const AudioStreamBasicDescription *) streamFormat;
{
    THROW_IF(AudioUnitSetProperty([self AudioUnit],
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  streamFormat,
                                  sizeof(AudioStreamBasicDescription)));
}


@end
