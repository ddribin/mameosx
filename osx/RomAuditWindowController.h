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
    IBOutlet NSObjectController * mControllerAlias;
    IBOutlet NSArrayController * mResultsController;
    IBOutlet NSPanel * mProgressPanel;

    NSString * mGameName;
    NSString * mStatus;
    NSString * mSearchString;
    NSMutableArray * mResults;
    BOOL mRunning;
    int mTotalRoms;
    int mCheckedRoms;
    double mCurrentProgress;
    BOOL mShowGood;
}

- (IBAction) verifyRoms: (id) sender;
- (IBAction) cancel: (id) sender;

- (double) currentProgress;

- (NSString *) status;

- (NSString *) gameName;
- (void) setGameName: (NSString *) gameName;

- (NSString *) searchString;
- (void) setSearchString: (NSString *) searchString;

- (BOOL) showGood;
- (void) setShowGood: (BOOL) showGood;

- (NSMutableArray *) results;
-  (void) setResults: (NSMutableArray *) results;

@end
