//
//  NXAudioUnit.m
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

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
