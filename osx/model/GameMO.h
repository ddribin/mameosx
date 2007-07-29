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

+ (NSEntityDescription *) entityInContext: (NSManagedObjectContext *) context;

+ (GameMO *) createInContext: (NSManagedObjectContext *) context;

+ (GameMO *) findWithShortName: (NSString *) shortName
                     inContext: (NSManagedObjectContext *) context;

+ (GameMO *) findOrCreateWithShortName: (NSString *) shortName
                             inContext: (NSManagedObjectContext *) context;

+ (NSArray *) gamesWithShortNames: (NSArray *) shortNames
                        inContext: (NSManagedObjectContext *) context;

+ (NSArray *) gamesWithShortNames: (NSArray *) shortNames
                  sortDescriptors: (NSArray *) sortDescriptors
                        inContext: (NSManagedObjectContext *) context;

+ (NSArray *) allGamesWithSortDesriptors: (NSArray *) sortDescriptors
                               inContext: (NSManagedObjectContext *) context;

+ (NSArray *) sortByShortName;

+ (NSArray *) sortByLongName;

- (void) toggleGroupMembership: (GroupMO *) group;

- (BOOL) isFavorite;
- (NSImage *) favoriteIcon;

- (unsigned) driverIndex;
- (void) setDriverIndex: (unsigned) theDriverIndex;

- (NSString *) displayName;
- (NSString *) auditStatusString;

@end
