//
//  MameUtilApp.m
//  mameosx
//
//  Created by Dave Dribin on 7/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MameUtilApp.h"

// MAME headers
#include "driver.h"
#include "clifront.h"

@implementation MameUtilApp

- (void) printUsage: (FILE *) stream;
{
    ddfprintf(stream, @"%@: Usage [OPTIONS] [<gamename|wildcard>]\n", DDCliApp);
}

- (void) printHelp;
{
    [self printUsage: stdout];
    printf("\n"
           "  -x, --listxml                 List game details\n"
           "  -l, --listfull                List driver names and descriptions\n"
           "  -s, --listsource              List source files\n"
           "  -c, --listclonse              List of clones\n"
           "      --listcrc                 List of CRCs\n"
           "      --version                 Display version and exit\n"
           "  -h, --help                    Display this help and exit\n"
           "\n"
           "A uitility application for MAME OS X.\n");
}

- (void) printVersion;
{
    ddprintf(@"%@ version %s\n", DDCliApp, CURRENT_MARKETING_VERSION);
}

- (void) application: (DDCliApplication *) app
    willParseOptions: (DDGetoptLongParser *) optionsParser;
{
    DDGetoptOption optionTable[] = 
    {
        // Long         Short   Argument options
        {@"listxml",    'x',    DDGetoptNoArgument},
        {@"listfull",   'l',    DDGetoptNoArgument},
        {@"listsource", 's',    DDGetoptNoArgument},
        {@"listclones", 'c',    DDGetoptNoArgument},
        {@"listcrc",    0,      DDGetoptNoArgument},

        {@"version",    0,      DDGetoptNoArgument},
        {@"help",       'h',    DDGetoptNoArgument},
        {nil,           0,      0},
    };
    [optionsParser addOptionsFromTable: optionTable];
}

- (int) application: (DDCliApplication *) app
   runWithArguments: (NSArray *) arguments;
{
    if (_help)
    {
        [self printHelp];
        return 0;
    }
    
    if (_version)
    {
        [self printVersion];
        return 0;
    }
    
    if ([arguments count] > 1)
    {
        ddfprintf(stderr, @"%@: Unexpected arguments\n", DDCliApp);
        [self printUsage: stderr];
        ddfprintf(stderr, @"Try `%@ --help' for more information.\n",
                  DDCliApp);
        return 1;
    }
    
    const char * game = "*";
    if ([arguments count] == 1)
    {
        game = [[arguments objectAtIndex: 0] UTF8String];
    }
    
    if (_listxml)
        cli_info_listxml(game);
    else if (_listfull)
        cli_info_listfull(game);
    else if (_listsource)
        cli_info_listsource(game);
    else if (_listclones)
        cli_info_listclones(game);
    else if (_listcrc)
        cli_info_listcrc(game);
    
    return 0;
}


@end
