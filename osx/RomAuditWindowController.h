//
//  RomAuditWindowController.h
//  mameosx
//
//  Created by Dave Dribin on 11/27/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RomAuditWindowController : NSWindowController
{
    IBOutlet NSProgressIndicator * mProgress;
    IBOutlet NSTableView * mResultsTable;
    IBOutlet NSTextView * mNotesView;
    IBOutlet NSArrayController * mResultsController;

    NSString * mGameName;
    NSString * mStatus;
    NSMutableArray * mResults;
}

- (IBAction) verifyRoms: (id) sender;

- (NSString *) status;
- (void) setStatus: (NSString *) status;
- (NSMutableArray *) results;
-  (void) setResults: (NSMutableArray *) results;

@end
