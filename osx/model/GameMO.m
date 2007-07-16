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
        return [NSImage imageNamed: @"Heart_16"];
    else
        return nil;
}

@end
