//
//  NXAudioException.m
//  mameosx
//
//  Created by Dave Dribin on 12/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NXAudioException.h"

NSString * NXAudioException = @"AudioException";

void NXThrowAudioIfErr(OSStatus err)
{
    if (err != 0)
    {
        NSString * reason = [NSString stringWithFormat: @"%ld: [%s]", err,
            GetMacOSStatusErrorString(err)];
        NSException * e = [NSException exceptionWithName: NXAudioException
                                                  reason: reason
                                                userInfo: nil];
        @throw e;
    }
}
