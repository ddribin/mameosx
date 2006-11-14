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

// Given a full path to the d/l dir, display the leaf name and the finder icon associated
// with that folder in the first item of the download folder popup.
//
- (void)setupRomDirectoryMenuWithPath:(NSString*)inDLPath
{
    NSMenuItem* placeholder = [mRomDirectory itemAtIndex:0];
    if (!placeholder)
        return;
    
    // get the finder icon and scale it down to 16x16
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:inDLPath];
    [icon setScalesWhenResized:YES];
    [icon setSize:NSMakeSize(16.0, 16.0)];
    
    // set the title to the leaf name and the icon to what we gathered above
    [placeholder setTitle:[[NSFileManager defaultManager] displayNameAtPath:inDLPath]];
    [placeholder setImage:icon];
    
    // ensure first item is selected
    [mRomDirectory selectItemAtIndex:0];
}

- (void)awakeFromNib
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * romPath = [defaults stringForKey: @"RomPath"];
    NSLog(@"romPath: %@", romPath);
    [self setupRomDirectoryMenuWithPath: romPath];
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
        // Update menu
        [self setupRomDirectoryMenuWithPath: newRomPath];
    }
    else
    {
        [mRomDirectory selectItemAtIndex: 0];
    }
}

@end
