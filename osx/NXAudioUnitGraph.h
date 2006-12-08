//
//  NXAudioUnitGraph.h
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

@class NXAudioUnitNode;

@interface NXAudioUnitGraph : NSObject
{
    AUGraph mGraph;
}

- (id) init;

- (void) dealloc;

- (AUGraph) AUGraph;

- (NXAudioUnitNode *) addNodeWithType: (OSType) type
                              subType: (OSType) subType;

- (NXAudioUnitNode *) addNodeWithType: (OSType) type
                              subType: (OSType) subType
                         manufacturer: (OSType) manufacturer;

- (void) connectNode: (NXAudioUnitNode *) sourceNode
               input: (UInt32) sourceInput
              toNode: (NXAudioUnitNode *) destNode
               input: (UInt32) destInput;

- (void) open;

- (void) update;

- (void) initialize;

- (void) uninitialize;

- (void) start;

- (void) stop;

@end
