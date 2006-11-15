//
//  MamePreferencesController.m
//  mameosx
//
//  Created by Dave Dribin on 11/14/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MamePreferencesController.h"

@interface MamePreferencesController (Private)

- (void) setPopUpMenu: (NSPopUpButton *) popupButton withPath: (NSString *) path;

- (void) chooseDirectoryForKey: (NSString *) userDataKey
                     withTitle: (NSString *) title;

- (void) chooseDirectoryDidEnd: (NSOpenPanel *) panel
                    returnCode: (int) returnCode
                   contextInfo: (void *) contextInfo;

@end

@implementation MamePreferencesController

- (id) init
{
    self = [super initWithWindowNibName: @"Preferences"];
    if (self == nil)
        return nil;
    
    return self;
}


- (void) awakeFromNib
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    mButtonsByKey = [[NSDictionary alloc] initWithObjectsAndKeys:
        mRomDirectory, @"RomPath",
        mSamplesDirectory, @"SamplePath",
        mArtworkDirectory, @"ArtworkPath",
        nil];

    NSString * romPath = [defaults stringForKey: @"RomPath"];
    NSString * samplePath = [defaults stringForKey: @"SamplePath"];
    NSString * artworkPath = [defaults stringForKey: @"ArtworkPath"];
    
    [self setPopUpMenu: mRomDirectory withPath: romPath];
    [self setPopUpMenu: mSamplesDirectory withPath: samplePath];
    [self setPopUpMenu: mArtworkDirectory withPath: artworkPath];
}

- (IBAction) chooseRomDirectory: (id) sender;
{
    [self chooseDirectoryForKey: @"RomPath"
                      withTitle: @"Choose ROM Directory"];
}

- (IBAction) chooseSamplesDirectory: (id) sender;
{
    [self chooseDirectoryForKey: @"SamplePath"
                      withTitle: @"Choose Sound Samples Directory"];
}

- (IBAction) chooseArtworkDirectory: (id) sender;
{
    [self chooseDirectoryForKey: @"ArtworkPath"
                      withTitle: @"Choose Artwork Directory"];
}

@end

@implementation MamePreferencesController (Private)

// Given a full path to a file, display the leaf name and the finder icon associated
// with that folder in the first item of the download folder popup.
//
- (void) setPopUpMenu: (NSPopUpButton *) popupButton withPath: (NSString *) path;
{
    NSMenuItem* placeholder = [popupButton itemAtIndex:0];
    if (!placeholder)
        return;
    
    // get the finder icon and scale it down to 16x16
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile: path];
    [icon setScalesWhenResized:YES];
    [icon setSize:NSMakeSize(16.0, 16.0)];
    
    // set the title to the leaf name and the icon to what we gathered above
    [placeholder setTitle: [path lastPathComponent]];
    [placeholder setImage: icon];
    
    // ensure first item is selected
    [popupButton selectItemAtIndex:0];
}


- (void) chooseDirectoryForKey: (NSString *) userDataKey
                     withTitle: (NSString *) title;
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    int result;
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    
    [panel setTitle: title];
    [panel setPrompt: @"Choose"];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setCanCreateDirectories: YES];
    [panel beginSheetForDirectory: [defaults stringForKey: userDataKey]
                             file: nil
                   modalForWindow: [self window]
                    modalDelegate: self
                   didEndSelector: @selector(chooseDirectoryDidEnd:returnCode:contextInfo:)
                      contextInfo: userDataKey];
}

- (void) chooseDirectoryDidEnd: (NSOpenPanel *) panel
                    returnCode: (int) returnCode
                   contextInfo: (void *) contextInfo;
{
    NSString * key = (NSString *) contextInfo;
    NSPopUpButton * button = [mButtonsByKey objectForKey: key];
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    if (returnCode == NSOKButton)
    {
        NSString * newRomPath = [panel filename];
        [defaults setValue: newRomPath forKey: key];
        // Update menu
        [self setPopUpMenu: button withPath: newRomPath];
    }
    else
    {
        [button selectItemAtIndex: 0];
    }
}

@end
