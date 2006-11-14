//
//  MamePreferencesController.m
//  mameosx
//
//  Created by Dave Dribin on 11/14/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MamePreferencesController.h"

@implementation MamePreferencesController

- (id) init
{
    self = [super initWithWindowNibName: @"Preferences"];
    return self;
}

- (IBAction) chooseRomDirectory: (id) sender;
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

    int result;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    [panel setTitle: @"Choose ROM Directory"];
    [panel setPrompt: @"Choose"];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    result = [panel runModalForDirectory: [defaults stringForKey: @"RomPath"]
                                    file: nil types: nil];
    if (result == NSOKButton)
    {
        NSString * newRomPath = [panel filename];
        [defaults setValue: newRomPath forKey: @"RomPath"];
    }
}

@end
