//
//  BackgroundUpdater.m
//  mameosx
//
//  Created by Dave Dribin on 7/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BackgroundUpdater.h"
#import "MameController.h"
#import "GameMO.h"
#import "driver.h"
#import "JRLog.h"

static NSString * kBackgroundUpdaterIdle = @"BackgroundUpdaterIdle";

@interface BackgroundUpdater (Private)

- (void) postIdleNotification;

- (void) idle: (NSNotification *) notification;

- (void) passOneComplete;
- (void) passTwoComplete;
- (void) passOne;
- (void) passTwo;

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
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(idle:)
                                                 name: kBackgroundUpdaterIdle
                                               object: self];

    return self;
}

- (void) start;
{
    mCurrentGameIndex = 0;
    [mShortNames removeAllObjects];
    mPass = 0;
    mCurrentGame = nil;
    mCurrentShortName = nil;
    mGameEnumerator = nil;
    
    JRLogDebug(@"Start background updater");
    [self postIdleNotification];
}

@end

@implementation BackgroundUpdater (Private)

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
    if (mCurrentGameIndex == driver_get_count())
    {
        if (mPass == 0)
            [self passOneComplete];
        else if (mPass == 1)
        {
            [self passTwoComplete];
            done = YES;
        }
    }
    
    if (!done)
    {
        if (mPass == 0)
            [self passOne];
        else if (mPass == 1)
            [self passTwo];

        mCurrentGameIndex++;
        [self postIdleNotification];
    }
}

- (void) passOneComplete;
{
    NSManagedObjectContext * context = [mController managedObjectContext];

    mPass = 1;
    JRLogDebug(@"Starting pass 1");
    [mShortNames sortUsingSelector: @selector(compare:)];
    
    // create the fetch request to get all Employees matching the IDs
    NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
    [fetchRequest setEntity:
        [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context]];
    [fetchRequest setPredicate: [NSPredicate predicateWithFormat: @"(shortName IN %@)", mShortNames]];
    
    // make sure the results are sorted as well
    [fetchRequest setSortDescriptors: [NSArray arrayWithObject:
        [[[NSSortDescriptor alloc] initWithKey: @"shortName"
                                     ascending:YES] autorelease]]];
    // Execute the fetch
    NSError *error = nil;
    NSArray * gamesMatchingNames = [context
        executeFetchRequest:fetchRequest error:&error];
    mCurrentGameIndex = 0;
    mGameEnumerator = [[gamesMatchingNames objectEnumerator] retain];
    mCurrentGame = [[mGameEnumerator nextObject] retain];
}

- (void) passTwoComplete;
{
    NSManagedObjectContext * context = [mController managedObjectContext];

    JRLogDebug(@"Idle done");

    [mCurrentGame release];
    [mCurrentShortName release];
    mCurrentGame = nil;
    mCurrentShortName = nil;
    
    NSError * error = nil;
    if (![context save: &error])
    {
        [mController handleCoreDataError: error];
    }
    return;
}

- (void) passOne;
{
    const game_driver * driver = drivers[mCurrentGameIndex];
    
    NSString * shortName = [NSString stringWithUTF8String: driver->name];
    [mShortNames addObject: shortName];
}

- (void) passTwo;
{
    NSManagedObjectContext * context = [mController managedObjectContext];
    const game_driver * driver = drivers[mCurrentGameIndex];

    mCurrentShortName = [mShortNames objectAtIndex: mCurrentGameIndex];
    GameMO * game = nil;
    if ((mCurrentGame != nil) && ([[mCurrentGame shortName] isEqualToString: mCurrentShortName]))
    {
        // game = mCurrentGame;
    }
    else
    {
        game = [NSEntityDescription insertNewObjectForEntityForName: @"Game"
                                             inManagedObjectContext: context];
    }
    
    if (game != nil)
    {
        NSString * shortName = [NSString stringWithUTF8String: driver->name];
        NSString * longName = [NSString stringWithUTF8String: driver->description];
        NSDictionary * gameDict = [NSDictionary dictionaryWithObjectsAndKeys:
            shortName, @"shortName", longName, @"longName", nil];
        [game setValuesForKeysWithDictionary: gameDict];
    }
    
#if 0
    if ((mCurrentGame == nil) || (![[mCurrentGame shortName] isEqualToString: mCurrentShortName]))
    {
        NSString * shortName = [NSString stringWithUTF8String: driver->name];
        NSString * longName = [NSString stringWithUTF8String: driver->description];
        NSDictionary * gameDict = [NSDictionary dictionaryWithObjectsAndKeys:
            shortName, @"shortName", longName, @"longName", nil];
        GameMO * game = [NSEntityDescription insertNewObjectForEntityForName: @"Game"
                                                      inManagedObjectContext: context];
        [game setValuesForKeysWithDictionary: gameDict];
    }
#endif
    
    if (mCurrentGame != nil)
    {
        [mCurrentGame release];
        mCurrentGame = [[mGameEnumerator nextObject] retain];
    }
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
