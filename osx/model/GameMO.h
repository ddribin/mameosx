#import "_GameMO.h"

@interface GameMO : _GameMO
{
    /*
     * Don't make this a transient property, since updating it marks the
     * objects as dirty, which slows down saves.
     *
     * http://lists.apple.com/archives/cocoa-dev/2005/Aug/msg01080.html
     */
    unsigned mDriverIndex;
}

- (void) toggleFavorite;

- (NSImage *) favoriteIcon;

- (unsigned) driverIndex;
- (void) setDriverIndex: (unsigned) theDriverIndex;

@end
