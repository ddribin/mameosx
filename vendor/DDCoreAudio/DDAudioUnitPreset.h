//
//  DDAudioUnitPreset.h
//  mameosx
//
//  Created by Dave Dribin on 12/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>


@interface DDAudioUnitPreset : NSObject
{
    AUPreset mPreset;
}

- (id) initWithAUPreset: (AUPreset) preset;

- (AUPreset) AUPreset;

- (SInt32) number;

- (NSString *) name;

- (BOOL) isEqualToPreset: (DDAudioUnitPreset *) preset;

- (NSString *) description;

@end
