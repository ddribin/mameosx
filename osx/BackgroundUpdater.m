//
//  BackgroundUpdater.m
//  mameosx
//
//  Created by Dave Dribin on 7/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BackgroundUpdater.h"
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

- (NSArray *) fetchAllGames;
- (GameMO *) gameWithShortName: (NSString *) shortName;

- (void) postIdleNotification;

- (void) idle: (NSNotification *) notification;

- (void) passOneComplete;
- (void) passTwoComplete;
- (void) passThreeComplete;
- (BOOL) passOne;
- (BOOL) passTwo;
- (BOOL) passThree;

@end

@implementation BackgroundUpdater

- (id) initWithMameController: (MameController *) controller;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mController = controller;
    mPass = 0;
    mShortNames = [[NSMutableArray alloc] init];
    mIndexByShortName = [[NSMutableDictionary alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(idle:)
                                                 name: kBackgroundUpdaterIdle
                                               object: self];

    return self;
}

- (void) dealloc
{
    [self freeResources];
    [super dealloc];
}

- (void) start;
{
    [self freeResources];
    
    mShortNames = [[NSMutableArray alloc] init];
    mIndexByShortName = [[NSMutableDictionary alloc] init];
    mCurrentGameIndex = 0;
    mPass = 0;
    
    JRLogDebug(@"Start background updater");
    [mController backgroundUpdateWillStart];
    [self postIdleNotification];
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
    NSNotification * note =
    [NSNotification notificationWithName: kBackgroundUpdaterIdle
                                  object: self];
    NSNotificationQueue * noteQueue = [NSNotificationQueue defaultQueue];
    [noteQueue enqueueNotification: note
                      postingStyle: NSPostWhenIdle];
}

- (void) idle: (NSNotification *) notification;
{
    BOOL done = NO;
    BOOL next = NO;
    
    if (mPass == 0)
        next = [self passOne];
    else if (mPass == 1)
        next = [self passTwo];
    else if (mPass == 2)
        next = [self passThree];
    else
        done = YES;
    
    if (next)
    {
        if (mPass == 0)
            [self passOneComplete];
        else if (mPass == 1)
            [self passTwoComplete];
        else if (mPass == 2)
            [self passThreeComplete];
        else
            done = YES;
    }
    
    if (!done)
        [self postIdleNotification];
    else
    {
        [self freeResources];
        JRLogDebug(@"Idle done");
    }
}

static NSTimeInterval mLastSave = 0;

- (BOOL) passOne;
{
    const game_driver * driver = drivers[mCurrentGameIndex];
    
    NSString * shortName = [NSString stringWithUTF8String: driver->name];
    [mIndexByShortName setObject: [NSNumber numberWithUnsignedInt: mCurrentGameIndex]
                          forKey: shortName];
    
    mCurrentGameIndex++;
    return (mCurrentGameIndex >= driver_get_count());
}

- (void) passOneComplete;
{
    NSManagedObjectContext * context = [mController managedObjectContext];

    mPass = 1;
    JRLogDebug(@"Starting pass 1");
    NSArray * shortNames = [mIndexByShortName allKeys];
    [mShortNames addObjectsFromArray: [shortNames sortedArrayUsingSelector: @selector(compare:)]];
    
    NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
    [fetchRequest setEntity:
        [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context]];
    [fetchRequest setPredicate: [NSPredicate predicateWithFormat: @"(shortName IN %@)", shortNames]];
    
    // make sure the results are sorted as well
    [fetchRequest setSortDescriptors: [NSArray arrayWithObject:
        [[[NSSortDescriptor alloc] initWithKey: @"shortName"
                                     ascending:YES] autorelease]]];
    // Execute the fetch
    JRLogDebug(@"Fetching current game list");
    NSError *error = nil;
    NSArray * gamesMatchingNames = [context
        executeFetchRequest:fetchRequest error:&error];
    JRLogDebug(@"Fetch done");
    mCurrentGameIndex = 0;
    mGameEnumerator = [[gamesMatchingNames objectEnumerator] retain];
    mCurrentGame = [[mGameEnumerator nextObject] retain];
    mLastSave = [NSDate timeIntervalSinceReferenceDate];
}

- (BOOL) passTwo;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    if ((mCurrentGameIndex % 1000) == 0)
    {
        JRLogDebug(@"Pass 2 index: %d", mCurrentGameIndex);
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
        game = [NSEntityDescription insertNewObjectForEntityForName: @"Game"
                                             inManagedObjectContext: context];
#else
        game = [mController newGame];
#endif
        NSString * shortName = [NSString stringWithUTF8String: driver->name];
        [game setShortName: shortName];
    }
    
    if (game != nil)
    {
        NSArray * currentKeys = [NSArray arrayWithObjects:
            @"longName", @"manufacturer", @"year", nil];
        NSDictionary * currentValues = [game dictionaryWithValuesForKeys: currentKeys];
        
        NSString * longName = [NSString stringWithUTF8String: driver->description];
        NSString * manufacturer = [NSString stringWithUTF8String: driver->manufacturer];
        NSString * year = [NSString stringWithUTF8String: driver->year];
        NSDictionary * newValues = [NSDictionary dictionaryWithObjectsAndKeys:
            longName, @"longName",
            manufacturer, @"manufacturer",
            year, @"year",
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
        game = [NSEntityDescription insertNewObjectForEntityForName: @"Game"
                                             inManagedObjectContext: context];
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
    return (mCurrentGameIndex >= driver_get_count());
}

- (void) passTwoComplete;
{
    NSManagedObjectContext * context = [mController managedObjectContext];

    mPass = 2;
    JRLogDebug(@"Pass 2 done");

    [mCurrentGame release];
    [mGameEnumerator release];
    mCurrentGame = nil;
    mGameEnumerator = nil;
    
    JRLogDebug(@"Saving: %d %d", [[context updatedObjects] count], [context hasChanges]);
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

#if 1
    NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
    [fetchRequest setEntity:
        [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context]];

    [fetchRequest setPredicate: [NSPredicate predicateWithFormat: @"(auditStatus == NIL)"]]; 
    
    // make sure the results are sorted as well
    [fetchRequest setSortDescriptors: [NSArray arrayWithObject:
        [[[NSSortDescriptor alloc] initWithKey: @"shortName"
                                     ascending:YES] autorelease]]];
    // Execute the fetch
    NSError * error = nil;
    JRLogDebug(@"Fetching games that need audit");
    NSArray * allGames = [context executeFetchRequest:fetchRequest error:&error];
    JRLogDebug(@"Games that need audit: %d", [allGames count]);
    [mController backgroundUpdateWillBeginAudits: [allGames count]];
    mCurrentGameIndex = 0;
    mGameEnumerator = [[allGames objectEnumerator] retain];
    mLastSave = [NSDate timeIntervalSinceReferenceDate];
#endif
}

- (BOOL) passThree;
{
    GameMO * game = [mGameEnumerator nextObject];
    if (game == nil)
        return YES;
    
    NSManagedObjectContext * context = [mController managedObjectContext];
    unsigned driverIndex = [game driverIndex];
    
    JRLogDebug(@"Auditing %@", [game shortName]);
    audit_record * auditRecords;
    int recordCount;
    int res;
    
    /* audit the ROMs in this set */
    recordCount = audit_images(driverIndex, AUDIT_VALIDATE_FAST, &auditRecords);
    RomAuditSummary * summary =
        [[RomAuditSummary alloc] initWithGameIndex: driverIndex
                                       recordCount: recordCount
                                           records: auditRecords];
    free(auditRecords);
    [summary autorelease];
    [game setAuditStatusValue: [summary status]];
    [game setAuditNotes: [summary notes]];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if ((now - mLastSave) > 15.0)
    {
        JRLogDebug(@"Saving");
        [mController saveAction: self];
        mLastSave = now;
    }
    
    [context processPendingChanges];
    
    [mController backgroundUpdateAuditStatus: mCurrentGameIndex];
    mCurrentGameIndex++;
    
    return NO;
}

- (void) passThreeComplete;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    
    JRLogDebug(@"Pass 3 done");
    [mController backgroundUpdateWillFinish];
    mPass = 3;
    
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
}

- (NSArray *) fetchAllGames;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity: [NSEntityDescription entityForName: @"Game"
                                    inManagedObjectContext: context]];
   
    [request setSortDescriptors: [NSArray arrayWithObject:
        [[[NSSortDescriptor alloc] initWithKey: @"shortName"
                                     ascending:YES] autorelease]]];

    NSError * error = nil;
    NSArray * results = [context executeFetchRequest: request error: &error];
    if (results == nil)
    {
        [mController handleCoreDataError: error];
    }
    return results;
}

- (GameMO *) gameWithShortName: (NSString *) shortName;
{
    NSManagedObjectModel * model = [mController managedObjectModel];
    NSDictionary * variables = [NSDictionary dictionaryWithObject: shortName
                                                           forKey: @"SHORT_NAME"];
    NSFetchRequest * request =
        [model fetchRequestFromTemplateWithName: @"gameWithShortName"
                          substitutionVariables: variables];
    
    NSError * error = nil;
    NSManagedObjectContext * context = [mController managedObjectContext];
    NSArray * results = [context executeFetchRequest: request error: &error];
    if (results == nil)
    {
        [mController handleCoreDataError: error];
        return nil;
    }
    
    NSAssert([results count] <= 1, @"No more than one result");
    if ([results count] == 0)
        return nil;
    else
        return [results objectAtIndex: 0];
}

@end
