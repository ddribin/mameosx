//
//  NXAudioUnitPreset.m
//  mameosx
//
//  Created by Dave Dribin on 12/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NXAudioUnitPreset.h"


@implementation NXAudioUnitPreset

- (id) initWithAUPreset: (AUPreset) preset;
{
    self = [super init];
    if (self == nil)
        return nil;

    mPreset = preset;
    
    return self;
}

- (AUPreset) AUPreset;
{
    return mPreset;
}

- (SInt32) number;
{
    return mPreset.presetNumber;
}

- (NSString *) name;
{
    return (NSString *) mPreset.presetName;
}

- (BOOL) isEqualToPreset: (NXAudioUnitPreset *) preset;
{
    if (preset == nil)
        return NO;
    NSString * myName = [self name];
    NSString * otherName = [preset name];
    return ((mPreset.presetNumber == preset->mPreset.presetNumber) &&
            ([myName isEqualToString: otherName]));
}

- (NSString *) description;
{
    return [NSString stringWithFormat: @"Preset number %d, name %@",
        mPreset.presetNumber, mPreset.presetName];
}

@end
