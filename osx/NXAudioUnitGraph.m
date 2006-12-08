//
//  NXAudioUnitGraph.m
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NXAudioUnitGraph.h"
#import "NXAudioUnitNode.h"
#import "NXAudioException.h"

#define THROW_IF NXThrowAudioIfErr

@implementation NXAudioUnitGraph

- (id) init;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    THROW_IF(NewAUGraph(&mGraph));
   
    return self;
}

- (void) dealloc;
{
    [super dealloc];
}

- (AUGraph) AUGraph;
{
    return mGraph;
}

- (NXAudioUnitNode *) addNodeWithType: (OSType) type
                              subType: (OSType) subType;
{
    return [self addNodeWithType: type
                         subType: subType
                    manufacturer: kAudioUnitManufacturer_Apple];
}

- (NXAudioUnitNode *) addNodeWithType: (OSType) type
                              subType: (OSType) subType
                         manufacturer: (OSType) manufacturer;
{
    ComponentDescription description;
    description.componentType = type;
    description.componentSubType = subType;
    description.componentManufacturer = manufacturer;
    description.componentFlags = 0;
    description.componentFlagsMask = 0;
    
    AUNode node;
    THROW_IF(AUGraphNewNode(mGraph, &description, 0, NULL, &node));
    return [[[NXAudioUnitNode alloc] initWithAUNode: node inGraph: self] autorelease];
}

- (void) removeNode: (NXAudioUnitNode *) node;
{
    THROW_IF(AUGraphRemoveNode(mGraph, [node AUNode]));
}

- (void) connectNode: (NXAudioUnitNode *) sourceNode
              output: (UInt32) sourceOutput
              toNode: (NXAudioUnitNode *) destNode
               input: (UInt32) destInput;
{
    THROW_IF(AUGraphConnectNodeInput(mGraph,
                                     [sourceNode AUNode], sourceOutput,
                                     [destNode AUNode], destInput));
}


- (void) disconnectNode: (NXAudioUnitNode *) node
                  input: (UInt32) input;
{
    THROW_IF(AUGraphDisconnectNodeInput(mGraph,
                                        [node AUNode], input));
}

- (void) open;
{
    THROW_IF(AUGraphOpen(mGraph));
}

- (void) update;
{
    THROW_IF(AUGraphUpdate(mGraph, NULL));
}

- (void) initialize;
{
    THROW_IF(AUGraphInitialize(mGraph));
}

- (void) uninitialize;
{
    THROW_IF(AUGraphUninitialize(mGraph));
}

- (void) start;
{
    THROW_IF(AUGraphStart(mGraph));
}

- (void) stop;
{
    THROW_IF(AUGraphStop(mGraph));
}

- (float) cpuLoad;
{
    Float32 cpuLoad;
    THROW_IF(AUGraphGetCPULoad(mGraph, &cpuLoad));
    return (float) cpuLoad;
}

@end
