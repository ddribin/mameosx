//
//  MameApplication.m
//  mameosx
//
//  Created by Dave Dribin on 1/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "MameApplication.h"
#import "MamePreferences.h"


@implementation MameApplication

+ initialize;
{
    NSLog(@"MameApplication +initialize");
    [[MamePreferences standardPreferences] registerDefaults];
}

@end
