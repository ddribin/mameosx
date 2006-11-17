/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>


@interface MamePreferencesController : NSWindowController
{
    IBOutlet NSPopUpButton * mRomDirectory;
    IBOutlet NSPopUpButton * mSamplesDirectory;
    IBOutlet NSPopUpButton * mArtworkDirectory;

    NSDictionary * mButtonsByKey;
}

- (IBAction) chooseRomDirectory: (id) sender;
- (IBAction) chooseSamplesDirectory: (id) sender;
- (IBAction) chooseArtworkDirectory: (id) sender;

@end
