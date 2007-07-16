#import "GameMO.h"

@implementation GameMO

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
