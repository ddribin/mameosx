//
//  NXAudioException.h
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString * NXAudioException;

void NXThrowAudioIfErr(OSStatus err);
