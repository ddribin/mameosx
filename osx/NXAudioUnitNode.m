//
//  NXAudioUnitNode.m
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NXAudioUnitNode.h"
#import "NXAudioUnitGraph.h"
#import "NXAudioUnit.h"
#import "NXAudioException.h"

#define THROW_IF NXThrowAudioIfErr

@implementation NXAudioUnitNode

- (id) initWithAUNode: (AUNode) node inGraph: (NXAudioUnitGraph *) graph;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mNode = node;
    mGraph = graph;
    
    return self;
}

- (AUNode) AUNode;
{
    return mNode;
}

- (NXAudioUnit *) audioUnit;
{
    AudioUnit audioUnit;
    THROW_IF(AUGraphGetNodeInfo([mGraph AUGraph],
                                [self AUNode],
                                NULL, NULL, NULL, &audioUnit));
    return [[[NXAudioUnit alloc] initWithAudioUnit: audioUnit] autorelease];
}

@end
