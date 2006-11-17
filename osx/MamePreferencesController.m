/*
 * Copyright (c) 2006 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "MamePreferencesController.h"
#import "MameConfiguration.h"

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
        mRomDirectory, MameRomPath,
        mSamplesDirectory, MameSamplePath,
        mArtworkDirectory, MameArtworkPath,
        nil];

    NSString * romPath = [defaults stringForKey: MameRomPath];
    NSString * samplePath = [defaults stringForKey: MameSamplePath];
    NSString * artworkPath = [defaults stringForKey: MameArtworkPath];
    
    [self setPopUpMenu: mRomDirectory withPath: romPath];
    [self setPopUpMenu: mSamplesDirectory withPath: samplePath];
    [self setPopUpMenu: mArtworkDirectory withPath: artworkPath];
}

- (IBAction) chooseRomDirectory: (id) sender;
{
    [self chooseDirectoryForKey: MameRomPath
                      withTitle: @"Choose ROM Directory"];
}

- (IBAction) chooseSamplesDirectory: (id) sender;
{
    [self chooseDirectoryForKey: MameSamplePath
                      withTitle: @"Choose Sound Samples Directory"];
}

- (IBAction) chooseArtworkDirectory: (id) sender;
{
    [self chooseDirectoryForKey: MameArtworkPath
                      withTitle: @"Choose Artwork Directory"];
}

@end

@implementation MamePreferencesController (Private)

// Given a full path to a file, display the leaf name and the finder icon associated
// with that folder in the first item of the download folder popup.
//
- (void) setPopUpMenu: (NSPopUpButton *) popupButton withPath: (NSString *) path;
{
    NSMenuItem* placeholder = [popupButton itemAtIndex: 0];
    if (!placeholder)
        return;
    
    // get the finder icon and scale it down to 16x16
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile: path];
    [icon setScalesWhenResized: YES];
    [icon setSize: NSMakeSize(16.0, 16.0)];
    
    // set the title to the leaf name and the icon to what we gathered above
    [placeholder setTitle: [path lastPathComponent]];
    [placeholder setImage: icon];
    
    // ensure first item is selected
    [popupButton selectItemAtIndex: 0];
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
        NSString * newPath = [panel filename];
        [defaults setValue: newPath forKey: key];
        // Update menu
        [self setPopUpMenu: button withPath: newPath];
    }
    else
    {
        [button selectItemAtIndex: 0];
    }
}

@end
