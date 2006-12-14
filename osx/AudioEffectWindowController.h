//
//  AudioEffectWindowController.h
//  mameosx
//
//  Created by Dave Dribin on 12/9/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MameView;

@interface AudioEffectWindowController : NSWindowController
{
    IBOutlet NSView * mContainerView;
    IBOutlet NSView * mNoEffectView;
    
    MameView * mMameView;
    NSView * mAudioUnitView;
    NSTimer * mCpuLoadTimer;
    float mCpuLoad;
}

- (id) initWithMameView: (MameView *) mameView;

- (MameView *) mameView;

- (float) cpuLoad;

- (BOOL) effectHasFactoryPresets;

@end
