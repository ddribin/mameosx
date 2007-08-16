//
//  BackgroundUpdater.m
//  mameosx
//
//  Created by Dave Dribin on 7/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BackgroundUpdater.h"
#import "BackgroundUpdater_sm.h"
#import "MameController.h"
#import "MamePreferences.h"
#import "RomAuditSummary.h"
#import "GameMO.h"
#import "GroupMO.h"
#import "JRLog.h"

#import "driver.h"
#import "audit.h"

static NSString * kBackgroundUpdaterIdle = @"BackgroundUpdaterIdle";

@interface BackgroundUpdater (Private)

- (void) freeResources;

- (void) postIdleNotification;

- (void) idle: (NSNotification *) notification;
- (void) save;
- (NSArray *) fetchGamesThatNeedAudit;

@end

@implementation BackgroundUpdater

- (id) initWithMameController: (MameController *) controller;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mController = controller;
    mRunning = NO;
    mShortNames = nil;
    mIndexByShortName = [[NSMutableDictionary alloc] init];
    mIdle = NO;
    mAuditing = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(idle:)
                                                 name: kBackgroundUpdaterIdle
                                               object: self];
    
    mFsm = [[BackgroundUpdaterContext alloc] initWithOwner: self];
    if ([[MamePreferences standardPreferences] backgroundUpdateDebug])
        [mFsm setDebugFlag: YES];
    [mFsm Init];

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self freeResources];
    [mFsm release];
    mFsm = nil;
    [super dealloc];
}

- (void) start;
{
    [mFsm Start];
}

- (void) pause;
{
    [mFsm Pause];
}

- (void) resume;
{
    [mFsm Resume];
    [self postIdleNotification];
}

- (BOOL) isRunning;
{
    return mRunning;
}

- (void) auditGames: (NSArray *) games;
{
    [mFsm AuditGames: games];
    mRunning = YES;
    [self postIdleNotification];
}

- (void) auditUnauditedGames;
{
    [mFsm AuditGames: [self fetchGamesThatNeedAudit]];
    mRunning = YES;
    [self postIdleNotification];
}

- (void) abortAudit;
{
    [mFsm AbortAudit];
}

- (BOOL) isIdle;
{
    return mIdle;
}

- (void) setIdle: (BOOL) idle;
{
    mIdle = idle;
}

- (BOOL) auditing;
{
    return mAuditing;
}

- (void) setAuditing: (BOOL) auditing;
{
    mAuditing = auditing;
}

#pragma mark -
#pragma mark State Machine Actions

- (void) saveState;
{
    mSavedRunning = mRunning;
    mRunning = NO;
}

- (void) restoreState;
{
    mRunning = mSavedRunning;
}

- (void) prepareToIndexByShortName;
{
    [self freeResources];
    
    mIndexByShortName = [[NSMutableDictionary alloc] init];
    mCurrentGameIndex = 0;
    
    JRLogDebug(@"Start background update");
    mRunning = YES;
    [mController backgroundUpdateWillStart];
    [mController setStatusText: @"Updating game list"];
    [self postIdleNotification];
}

- (void) indexByShortName;
{
    const game_driver * driver = drivers[mCurrentGameIndex];
    
    NSString * shortName = [NSString stringWithUTF8String: driver->name];
    [mIndexByShortName setObject: [NSNumber numberWithUnsignedInt: mCurrentGameIndex]
                          forKey: shortName];
    
    mCurrentGameIndex++;
    if (mCurrentGameIndex >= driver_list_get_count(drivers))
        mWorkDone = YES;
}

- (void) prepareToUpdateGameList;
{
    /*
     * Setup two sorted arrays, mShortNames and mGameEnumerator.
     * Loop through both arrays, using a similar algorithm as described here:
     *
     * Implementing Find-or-Create Efficiently
     * http://developer.apple.com/documentation/Cocoa/Conceptual/CoreData/Articles/cdImporting.htm
     *
     * Except, we always update the GameMO from the driver, to ensure it's
     * data is up-to-date.
     */
    
    NSManagedObjectContext * context = [mController managedObjectContext];
    
    JRLogDebug(@"Prepare to update game list");
    NSArray * shortNames = [mIndexByShortName allKeys];
    mShortNames = [[shortNames sortedArrayUsingSelector: @selector(compare:)] retain];
    
    // Execute the fetch
    JRLogDebug(@"Fetching current game list");
    NSArray * gamesMatchingNames = [GameMO gamesWithShortNames: shortNames
                                               sortDescriptors: [GameMO sortByShortName]
                                                     inContext: context];
    JRLogDebug(@"Fetch done");
    mCurrentGameIndex = 0;
    mGameEnumerator = [[gamesMatchingNames objectEnumerator] retain];
    mCurrentGame = [[mGameEnumerator nextObject] retain];
    mLastSave = [NSDate timeIntervalSinceReferenceDate];
}

- (void) updateGameList;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    if ((mCurrentGameIndex % 1000) == 0)
    {
        JRLogDebug(@"Update game list index: %d", mCurrentGameIndex);
    }

    NSString * currentShortName = [mShortNames objectAtIndex: mCurrentGameIndex];
    unsigned driverIndex = [[mIndexByShortName objectForKey: currentShortName] unsignedIntValue];
    const game_driver * driver = drivers[driverIndex];
    GameMO * game = nil;
    NSComparisonResult comparison = NSOrderedDescending;
    BOOL advanceToNextGame = NO;
    if (mCurrentGame != nil)
        comparison = [[mCurrentGame shortName] compare: currentShortName];
    
    if (comparison == NSOrderedDescending)
    {
        // Create new game
        game = [GameMO createInContext: context];
        NSString * shortName = [NSString stringWithUTF8String: driver->name];
        [game setShortName: shortName];
        advanceToNextGame = NO;
    }
    else if (comparison == NSOrderedAscending)
    {
        // Delete current game
        [context deleteObject: mCurrentGame];
        game = nil;
        advanceToNextGame = YES;
    }
    else // (comparison == NSOrderedSame)
    {
        // Update
        game = mCurrentGame;
        advanceToNextGame = YES;
    }
    
    if (game != nil)
    {
        NSArray * currentKeys = [NSArray arrayWithObjects:
            @"longName", @"manufacturer", @"year", @"parentShortName", nil];
        NSDictionary * currentValues = [game dictionaryWithValuesForKeys: currentKeys];
        
        NSString * longName = [NSString stringWithUTF8String: driver->description];
        NSString * manufacturer = [NSString stringWithUTF8String: driver->manufacturer];
        NSString * year = [NSString stringWithUTF8String: driver->year];
        
        id parentShortName = [NSNull null];
        const game_driver * parentDriver = driver_get_clone(driver);
        if (parentDriver != NULL)
        {
            parentShortName = [NSString stringWithUTF8String: parentDriver->name];
        }
        
        NSDictionary * newValues = [NSDictionary dictionaryWithObjectsAndKeys:
            longName, @"longName",
            manufacturer, @"manufacturer",
            year, @"year",
            parentShortName, @"parentShortName",
            nil];
        
        if (![currentValues isEqualToDictionary: newValues])
        {
            [game setValuesForKeysWithDictionary: newValues];
        }
        [game setDriverIndex: driverIndex];
    }
    
    if (advanceToNextGame)
    {
        [mCurrentGame release];
        mCurrentGame = [[mGameEnumerator nextObject] retain];
    }
    mCurrentGameIndex++;
    
    if (mCurrentGameIndex >= driver_list_get_count(drivers))
        mWorkDone = YES;
}

- (void) prepareToAuditAllGames;
{
    JRLogDebug(@"Prepare to audit all games");
    
    [mCurrentGame release];
    [mGameEnumerator release];
    mCurrentGame = nil;
    mGameEnumerator = nil;
    
    [self save];
    NSArray * gamesThatNeedAudit = [NSArray array];
    if ([[MamePreferences standardPreferences] auditAtStartup])
        gamesThatNeedAudit = [self fetchGamesThatNeedAudit];

    [self prepareToAuditGames: gamesThatNeedAudit];
}

- (void) prepareToAuditGames: (NSArray *) games;
{
    JRLogDebug(@"Games that need audit: %d", [games count]);
    
    [mController backgroundUpdateWillBeginAudits: [games count]];
    mCurrentGameIndex = 0;
    mGameEnumerator = [[games objectEnumerator] retain];
    mLastSave = [NSDate timeIntervalSinceReferenceDate];
    mLastStatus = [[NSDate distantPast] timeIntervalSinceReferenceDate];
}

- (void) auditGames;
{
    GameMO * game = [mGameEnumerator nextObject];
    if (game == nil)
    {
        mWorkDone = YES;
        return;
    }
    
    [game audit];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if ((now - mLastStatus) > 0.25)
    {
        NSString * message = [NSString stringWithFormat: @"Auditing %@",
            [game longName]];
        [mController setStatusText: message];
        mLastStatus = now;
    }
    
    if ((now - mLastSave) > 15.0)
    {
        JRLogDebug(@"Saving");
        [self save];
        mLastSave = now;
    }
    
    NSManagedObjectContext * context = [mController managedObjectContext];
    [context processPendingChanges];
    [mController rearrangeGames];
    
    [mController backgroundUpdateAuditStatus: mCurrentGameIndex];
    mCurrentGameIndex++;
}

- (void) cleanUp;
{
    JRLogDebug(@"Cleaning up");
    [mController backgroundUpdateWillFinish];
    
    [mGameEnumerator release];
    mGameEnumerator = nil;
    
    [self save];

    [self freeResources];
    [mController setStatusText: @""];
    mRunning = NO;
    JRLogDebug(@"Background update done");
}

- (void) defaultWork;
{
    // Should never really get here, so just make sure everything is cleaned up,
    // and make sure we don't idle again.
    [self freeResources];
    mRunning = NO;
}

@end

@implementation BackgroundUpdater (Private)

- (void) freeResources;
{
    [mShortNames release];
    [mIndexByShortName release];
    [mCurrentGame release];
    [mGameEnumerator release];
    
    mShortNames = nil;
    mIndexByShortName = nil;
    mCurrentGame = nil;
    mGameEnumerator = nil;
}


- (void) postIdleNotification;
{
    if (!mRunning)
        return;

    NSNotification * note =
    [NSNotification notificationWithName: kBackgroundUpdaterIdle
                                  object: self];
    NSNotificationQueue * noteQueue = [NSNotificationQueue defaultQueue];
    [noteQueue enqueueNotification: note
                      postingStyle: NSPostWhenIdle];
}

- (void) idle: (NSNotification *) notification;
{
    mWorkDone = NO;
    [mFsm DoWork];
    if (mWorkDone)
        [mFsm WorkDone];
    
    [self postIdleNotification];
}

- (void) save;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    if ([context hasChanges])
    {
        JRLogDebug(@"Saving: %d", [[context updatedObjects] count]);
        [mController saveAction: self];
        JRLogDebug(@"Save done");
    }
    else
        JRLogDebug(@"Skipping save");
}

- (NSArray *) fetchGamesThatNeedAudit;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    NSFetchRequest * fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
    [fetchRequest setEntity: [GameMO entityInContext: context]];
    
    [fetchRequest setPredicate: [NSPredicate predicateWithFormat: @"(auditStatus == NIL)"]]; 
    
    // make sure the results are sorted as well
    [fetchRequest setSortDescriptors: [GameMO sortByLongName]];
    // Execute the fetch
    NSError * error = nil;
    JRLogDebug(@"Fetching games that need audit");
    return [context executeFetchRequest: fetchRequest error: &error];
}

@end
