/*
 * Copyright (c) 2006 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

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

- (void) removeNode: (NXAudioUnitNode *) node;

- (void) connectNode: (NXAudioUnitNode *) sourceNode
              output: (UInt32) sourceOutput
              toNode: (NXAudioUnitNode *) destNode
               input: (UInt32) destInput;

- (void) disconnectNode: (NXAudioUnitNode *) node
                  input: (UInt32) input;

- (void) open;

- (void) update;

- (void) initialize;

- (void) uninitialize;

- (void) start;

- (void) stop;

- (float) cpuLoad;

@end
