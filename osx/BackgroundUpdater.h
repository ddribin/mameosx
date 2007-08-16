//
//  BackgroundUpdater.h
//  mameosx
//
//  Created by Dave Dribin on 7/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MameController;
@class GameMO;
@class BackgroundUpdaterContext;

@interface BackgroundUpdater : NSObject
{
    BackgroundUpdaterContext * mFsm;

    // Resources that get released after background completion
    BOOL mRunning;
    BOOL mSavedRunning;
    BOOL mWorkDone;
    unsigned mCurrentGameIndex;
    NSArray * mShortNames;
    NSMutableDictionary * mIndexByShortName;
    GameMO * mCurrentGame;
    NSEnumerator * mGameEnumerator;
    NSTimeInterval mLastSave;
    NSTimeInterval mLastStatus;
    BOOL mIdle;
    
    // Weak references
    MameController * mController;
}

- (id) initWithMameController: (MameController *) controller;

- (void) start;
- (void) pause;
- (void) resume;

- (BOOL) isRunning;

- (void) auditGames: (NSArray *) games;

- (BOOL) isIdle;
- (void) setIdle: (BOOL) idle;

#pragma mark -
#pragma mark State Machine Actions

- (void) saveState;
- (void) restoreState;

- (void) prepareToIndexByShortName;
- (void) indexByShortName;
- (void) prepareToUpdateGameList;
- (void) updateGameList;
- (void) prepareToAuditAllGames;
- (void) prepareToAuditSelectedGames: (NSArray *) selectedGames;
- (void) auditGames;
- (void) cleanUp;

@end
