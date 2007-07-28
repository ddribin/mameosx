#import "GameMO.h"
#import "GroupMO.h"

@implementation GameMO

+ (void)initialize
{
    if (self == [GameMO class])
    {
        NSArray *keys = [NSArray arrayWithObjects: @"groups", nil];
        [self setKeys: keys triggerChangeNotificationsForDependentKey: @"favoriteIcon"];
    }
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

- (NSImage *) favoriteIcon;
{
    GroupMO * favorites =
        [GroupMO findOrCreateGroupWithName: GroupFavorites
                                 inContext: [self managedObjectContext]];
    BOOL isFavorite = [[favorites membersSet] containsObject: self];
    
    if (isFavorite)
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
