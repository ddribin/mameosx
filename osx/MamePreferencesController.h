//
//  MamePreferencesController.h
//  mameosx
//
//  Created by Dave Dribin on 11/14/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

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
