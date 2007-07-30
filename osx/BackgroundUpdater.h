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
    int mPass;
    BOOL mRunning;
    unsigned mCurrentGameIndex;
    NSMutableArray * mShortNames;
    NSMutableDictionary * mIndexByShortName;
    GameMO * mCurrentGame;
    NSEnumerator * mGameEnumerator;
    NSTimeInterval mLastSave;
    NSTimeInterval mLastStatus;
    BackgroundUpdaterContext * mFsm;
    BOOL mWorkDone;
    
    // Weak references
    MameController * mController;
}

- (id) initWithMameController: (MameController *) controller;

- (void) start;

- (BOOL) isRunning;

#pragma mark -
#pragma mark State Machine Actions

- (void) prepareToIndexByShortName;
- (void) indexByShortName;
- (void) prepareToUpdateGameList;
- (void) updateGameList;
- (void) preprateToAuditGames;
- (void) auditGames;
- (void) cleanUp;

@end
