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
    NSArray * mEffectComponents;
    int mCurrentEffectIndex;
}

- (id) initWithMameView: (MameView *) mameView;

- (MameView *) mameView;

- (float) cpuLoad;

- (NSArray *) effectComponents;

- (int) currentEffectIndex;

- (void) setCurrentEffectIndex: (int) effectIndex;

@end
