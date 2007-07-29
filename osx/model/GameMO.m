#import "GameMO.h"
#import "GroupMO.h"
#import "NSXReturnThrowError.h"
#import "audit.h"

@implementation GameMO

+ (void)initialize
{
    if (self == [GameMO class])
    {
        NSArray *keys = [NSArray arrayWithObjects: @"groups", nil];
        [self setKeys: keys triggerChangeNotificationsForDependentKey: @"favoriteIcon"];
        [self setKeys: keys triggerChangeNotificationsForDependentKey: @"favorite"];
    }
}

+ (NSEntityDescription *) entityInContext: (NSManagedObjectContext *) context;
{
    return [NSEntityDescription entityForName: @"Game"
                       inManagedObjectContext: context];
}

+ (GameMO *) createInContext: (NSManagedObjectContext *) context;
{
    [NSEntityDescription insertNewObjectForEntityForName: @"Game"
                                  inManagedObjectContext: context];
}

+ (GameMO *) findWithShortName: (NSString *) shortName
                     inContext: (NSManagedObjectContext *) context;
{
    NSManagedObjectModel * model = [[context persistentStoreCoordinator] managedObjectModel];
    NSDictionary * variables = [NSDictionary dictionaryWithObject: shortName
                                                           forKey: @"SHORT_NAME"];
    NSFetchRequest * request =
        [model fetchRequestFromTemplateWithName: @"gameWithShortName"
                          substitutionVariables: variables];
    
    NSError * error = nil;
    NSArray * results = [context executeFetchRequest: request error: &error];
    if (results == nil)
    {
        NSXRaiseError(error);
    }
    
    NSAssert([results count] <= 1, @"No more than one result");
    if ([results count] == 0)
        return nil;
    else
        return [results objectAtIndex: 0];
}

+ (GameMO *) findOrCreateWithShortName: (NSString *) shortName
                             inContext: (NSManagedObjectContext *) context;
{
    GameMO * game = [self findWithShortName: shortName inContext: context];
    if (game == nil)
    {
        game = [self createInContext: context];
        [game setShortName: shortName];
    }
    return game;
}

+ (NSArray *) gamesWithShortNames: (NSArray *) shortNames
                        inContext: (NSManagedObjectContext *) context;
{
    return [self gamesWithShortNames: shortNames
                     sortDescriptors: nil inContext: context];
}

+ (NSArray *) gamesWithShortNames: (NSArray *) shortNames
                  sortDescriptors: (NSArray *) sortDescriptors
                        inContext: (NSManagedObjectContext *) context;
{
    NSManagedObjectModel * model = [[context persistentStoreCoordinator] managedObjectModel];
    NSDictionary * variables = [NSDictionary dictionaryWithObject: shortNames
                                                           forKey: @"SHORT_NAMES"];
    NSFetchRequest * request =
        [model fetchRequestFromTemplateWithName: @"gamesWithShortNames"
                          substitutionVariables: variables];
    if (sortDescriptors != nil)
    {
        [request setSortDescriptors: sortDescriptors];
    }
    
    NSError * error = nil;
    NSArray * results = [context executeFetchRequest: request error: &error];
    if (results == nil)
    {
        NSXRaiseError(error);
    }
    
    return results;
}

+ (NSArray *) allGamesWithSortDesriptors: (NSArray *) sortDescriptors
                               inContext: (NSManagedObjectContext *) context;
{
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity: [self entityInContext: context]];
    
    if (sortDescriptors != nil)
    {
        [request setSortDescriptors: sortDescriptors];
    }
    
    NSError * error = nil;
    NSArray * results = [context executeFetchRequest: request error: &error];
    if (results == nil)
    {
        NSXRaiseError(error);
    }
    return results;
}

+ (NSArray *) sortByShortName;
{
    return [NSArray arrayWithObject:
            [[[NSSortDescriptor alloc] initWithKey: @"shortName"
                                         ascending: YES] autorelease]];
}

+ (NSArray *) sortByLongName;
{
    NSSortDescriptor * descriptor =
        [[NSSortDescriptor alloc] initWithKey: @"longName"
                                    ascending: YES
                                     selector: @selector(caseInsensitiveCompare:)];
    return [NSArray arrayWithObject: [descriptor autorelease]];
}

- (void) toggleGroupMembership: (GroupMO *) group;
{
#if 0
    NSMutableSet * groups = [self groupsSet];
    if ([groups containsObject: group])
        [groups removeObject: group];
    else
        [groups addObject: group];
#else
    NSMutableSet * members = [group membersSet];
    if ([members containsObject: self])
        [members removeObject: self];
    else
        [members addObject: self];
#endif
}

- (BOOL) isFavorite;
{
    GroupMO * favorites =
        [GroupMO findOrCreateGroupWithName: GroupFavorites
                                 inContext: [self managedObjectContext]];
    return [[favorites membersSet] containsObject: self];
}

- (NSImage *) favoriteIcon;
{
    if ([self isFavorite])
        return [NSImage imageNamed: @"favorite-16"];
    else
        return nil;
}

- (NSString *) displayName;
{
    return [NSString stringWithFormat:
        @"%@: %@, %@", [self shortName], [self manufacturer], [self year]];
}

- (NSString *) auditStatusString;
{
    NSNumber * auditStatus = [self auditStatus];
    if (auditStatus == nil)
        return @"N/A";
    
    switch ([auditStatus intValue])
    {
        case INCORRECT:
            return @"Bad";
            
        case CORRECT:
            return @"Good";
            
        case BEST_AVAILABLE:
            return @"Best Available";
            
        case NOTFOUND:
            return @"Not Found";
            
        default:
            return @"N/A";
    }
}


//=========================================================== 
//  driverIndex 
//=========================================================== 
- (unsigned) driverIndex
{
    return mDriverIndex;
}

- (void) setDriverIndex: (unsigned) theDriverIndex
{
    mDriverIndex = theDriverIndex;
}

@end
