//
//  mameosx-util-main.m
//  mameosx
//
//  Created by Dave Dribin on 6/29/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DDCommandLineInterface.h"
#import "MameUtilApp.h"

int main(int argc, char * argv[])
{
    return DDCliAppRunWithClass([MameUtilApp class]);
}