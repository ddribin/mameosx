#import "GameMO.h"
#import "GroupMO.h"
#import "NSXReturnThrowError.h"

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

+ (NSArray *) gamesWithShortNames: (NSArray *) shortNames
                        inContext: (NSManagedObjectContext *) context;
{
    NSManagedObjectModel * model = [[context persistentStoreCoordinator] managedObjectModel];
    NSDictionary * variables = [NSDictionary dictionaryWithObject: shortNames
                                                           forKey: @"SHORT_NAMES"];
    NSFetchRequest * request =
        [model fetchRequestFromTemplateWithName: @"gamesWithShortNames"
                          substitutionVariables: variables];
    
    NSError * error = nil;
    NSArray * results = [context executeFetchRequest: request error: &error];
    if (results == nil)
    {
        NSXRaiseError(error);
    }
    
    return results;
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
