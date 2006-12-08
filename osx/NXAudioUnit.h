//
//  NXAudioUnit.h
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>

@interface NXAudioUnit : NSObject
{
    AudioUnit mAudioUnit;
}

- (id) initWithAudioUnit: (AudioUnit) audioUnit;

- (AudioUnit) AudioUnit;

- (void) setRenderCallback: (AURenderCallback) callback
                   context: (void *) context;

- (void) setBypass: (BOOL) bypass;

- (void) setStreamFormatWithDescription:
    (const AudioStreamBasicDescription *) streamFormat;

@end
