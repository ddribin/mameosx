//
//  NXAudioUnitNode.h
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>


@class NXAudioUnitGraph;
@class NXAudioUnit;

@interface NXAudioUnitNode : NSObject
{
    AUNode mNode;
    NXAudioUnitGraph * mGraph;
}

- (id) initWithAUNode: (AUNode) node inGraph: (NXAudioUnitGraph *) graph;

- (AUNode) AUNode;

- (NXAudioUnit *) audioUnit;

@end
