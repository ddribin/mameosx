#import "GameMO.h"

@implementation GameMO

+ (void)initialize
{
    if (self == [GameMO class])
    {
        NSArray *keys = [NSArray arrayWithObjects: @"favorite", nil];
        [self setKeys: keys triggerChangeNotificationsForDependentKey: @"favoriteIcon"];
    }
}

- (void) toggleFavorite;
{
    BOOL favorite = [self favoriteValue];
    [self setFavoriteValue: !favorite];
}

- (NSImage *) favoriteIcon;
{
    if ([self favoriteValue])
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
