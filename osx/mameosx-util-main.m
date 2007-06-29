//
//  mameosx-util-main.m
//  mameosx
//
//  Created by Dave Dribin on 6/29/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

// MAME headers
#include "driver.h"
#include "clifront.h"

int main(int argc, char * argv[])
{
    int result = 0;
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    cli_info_listxml("pacman");
    
    [pool release];
    return 0;
}