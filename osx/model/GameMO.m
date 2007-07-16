#import "GameMO.h"

@implementation GameMO

- (void) toggleFavorite;
{
    BOOL favorite = [self favoriteValue];
    [self setFavoriteValue: !favorite];
}

@end
