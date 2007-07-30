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
#import "RomAuditSummary.h"
#import "GameMO.h"
#import "GroupMO.h"
#import "JRLog.h"

#import "driver.h"
#import "audit.h"

static NSString * kBackgroundUpdaterIdle = @"BackgroundUpdaterIdle";

static NSArray * sAllGames = nil;

@interface BackgroundUpdater (Private)

- (void) freeResources;

- (void) postIdleNotification;

- (NSArray *) fetchAllGames;
- (GameMO *) gameWithShortName: (NSString *) shortName;

- (void) idle: (NSNotification *) notification;

@end

@implementation BackgroundUpdater

- (id) initWithMameController: (MameController *) controller;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mController = controller;
    mRunning = NO;
    mShortNames = [[NSMutableArray alloc] init];
    mIndexByShortName = [[NSMutableDictionary alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(idle:)
                                                 name: kBackgroundUpdaterIdle
                                               object: self];
    
    mFsm = [[BackgroundUpdaterContext alloc] initWithOwner: self];
    // [mFsm setDebugFlag: YES];
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
    
    mShortNames = [[NSMutableArray alloc] init];
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
    if (mCurrentGameIndex >= driver_get_count())
        mWorkDone = YES;
}

- (void) prepareToUpdateGameList;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    
    JRLogDebug(@"Prepare to update game list");
    NSArray * shortNames = [mIndexByShortName allKeys];
    [mShortNames addObjectsFromArray: [shortNames sortedArrayUsingSelector: @selector(compare:)]];
    
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
#if 0
        NSError * error = nil;
        if (![context save: &error])
        {
            [mController handleCoreDataError: error];
        }
#endif
    }
#if 1
    NSString * currentShortName = [mShortNames objectAtIndex: mCurrentGameIndex];
    unsigned driverIndex = [[mIndexByShortName objectForKey: currentShortName] unsignedIntValue];
    const game_driver * driver = drivers[driverIndex];
    GameMO * game = nil;
    if ((mCurrentGame != nil) && ([[mCurrentGame shortName] isEqualToString: currentShortName]))
    {
        game = mCurrentGame;
    }
    else
    {
#if 1
        game = [GameMO createInContext: context];
#else
        game = [mController newGame];
#endif
        NSString * shortName = [NSString stringWithUTF8String: driver->name];
        [game setShortName: shortName];
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
    }
#else
    unsigned driverIndex = mCurrentGameIndex;
    const game_driver * driver = drivers[mCurrentGameIndex];
    NSString * shortName = [NSString stringWithUTF8String: driver->name];
    NSString * longName = [NSString stringWithUTF8String: driver->description];
    GameMO * game = [self gameWithShortName: shortName];
    if (game == nil)
    {
#if 0
        game = [GameMO createInContext: context];
#else
        game = [mController newGame];
#endif
        [game setShortName: shortName];
        [game setLongName: longName];
    }
#endif
    [game setDriverIndex: driverIndex];
    
    if (mCurrentGame != nil)
    {
        [mCurrentGame release];
        mCurrentGame = [[mGameEnumerator nextObject] retain];
    }
    mCurrentGameIndex++;
    
    if (mCurrentGameIndex >= driver_get_count())
        mWorkDone = YES;
}

- (void) preprateToAuditGames;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    
    JRLogDebug(@"Prepare to audit games");
    
    [mCurrentGame release];
    [mGameEnumerator release];
    mCurrentGame = nil;
    mGameEnumerator = nil;
    
    if ([context hasChanges])
    {
        JRLogDebug(@"Saving: %d", [[context updatedObjects] count]);
        NSError * error = nil;
        if (![context save: &error])
        {
            [mController handleCoreDataError: error];
        }
        JRLogDebug(@"Save done");
    }
    else
        JRLogDebug(@"Skipping save");
    
#if 1
    NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
    [fetchRequest setEntity: [GameMO entityInContext: context]];
    
    [fetchRequest setPredicate: [NSPredicate predicateWithFormat: @"(auditStatus == NIL)"]]; 
    
    // make sure the results are sorted as well
    [fetchRequest setSortDescriptors: [GameMO sortByLongName]];
    // Execute the fetch
    NSError * error = nil;
    JRLogDebug(@"Fetching games that need audit");
    NSArray * allGames = [context executeFetchRequest:fetchRequest error:&error];
    JRLogDebug(@"Games that need audit: %d", [allGames count]);
    [mController backgroundUpdateWillBeginAudits: [allGames count]];
    mCurrentGameIndex = 0;
    mGameEnumerator = [[allGames objectEnumerator] retain];
    mLastSave = [NSDate timeIntervalSinceReferenceDate];
    mLastStatus = [[NSDate distantPast] timeIntervalSinceReferenceDate];
#endif
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
        [mController saveAction: self];
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
    NSManagedObjectContext * context = [mController managedObjectContext];
    
    JRLogDebug(@"Cleaning up");
    [mController backgroundUpdateWillFinish];
    
    [mGameEnumerator release];
    mGameEnumerator = nil;
    
    if ([context hasChanges])
    {
        JRLogDebug(@"Saving");
        NSError * error = nil;
        if (![context save: &error])
        {
            [mController handleCoreDataError: error];
        }
        JRLogDebug(@"Save done");
    }
    else
        JRLogDebug(@"Skipping save");

    [self freeResources];
    [mController setStatusText: @""];
    mRunning = NO;
    JRLogDebug(@"Background update done");
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

- (NSArray *) fetchAllGames;
{
    return [GameMO allGamesWithSortDesriptors: [GameMO sortByShortName]
                                    inContext: [mController managedObjectContext]];
}

- (GameMO *) gameWithShortName: (NSString *) shortName;
{
    return [GameMO findWithShortName: shortName
                           inContext: [mController managedObjectContext]];
}

@end
