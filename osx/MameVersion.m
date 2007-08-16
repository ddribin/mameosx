//
//  MameVersion.m
//  mameosx
//
//  Created by Dave Dribin on 8/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MameVersion.h"


@implementation MameVersion

+ (NSString *) marketingVersion;
{
    NSBundle * mainBundle = [NSBundle mainBundle];
    return [[mainBundle infoDictionary] objectForKey: @"CFBundleShortVersionString"];
}

@end
