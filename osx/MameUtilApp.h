//
//  MameUtilApp.h
//  mameosx
//
//  Created by Dave Dribin on 7/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DDCommandLineInterface.h"

@interface MameUtilApp : NSObject <DDCliApplicationDelegate>
{
    BOOL _listxml;
    BOOL _listfull;
    BOOL _listsource;
    BOOL _listclones;
    BOOL _listcrc;
    BOOL _version;
    BOOL _help;
}

- (void) application: (DDCliApplication *) app
    willParseOptions: (DDGetoptLongParser *) optionsParser;

- (int) application: (DDCliApplication *) app
   runWithArguments: (NSArray *) arguments;

@end
