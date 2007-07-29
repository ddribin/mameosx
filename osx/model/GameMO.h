#import "_GameMO.h"

@class GroupMO;

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

+ (NSArray *) gamesWithShortNames: (NSArray *) shortNames
                        inContext: (NSManagedObjectContext *) context;

- (void) toggleGroupMembership: (GroupMO *) group;

- (BOOL) isFavorite;
- (NSImage *) favoriteIcon;

- (unsigned) driverIndex;
- (void) setDriverIndex: (unsigned) theDriverIndex;

- (NSString *) displayName;

@end
