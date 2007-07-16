// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to GameMO.h instead.

#import <CoreData/CoreData.h>



@class GameMO;


@interface _GameMO : NSManagedObject {}


- (NSString*)year;
- (void)setYear:(NSString*)value_;

//- (BOOL)validateYear:(id*)value_ error:(NSError**)error_;



- (NSNumber*)driverIndex;
- (void)setDriverIndex:(NSNumber*)value_;

- (int)driverIndexValue;
- (void)setDriverIndexValue:(int)value_;

//- (BOOL)validateDriverIndex:(id*)value_ error:(NSError**)error_;



- (NSNumber*)favorite;
- (void)setFavorite:(NSNumber*)value_;

- (BOOL)favoriteValue;
- (void)setFavoriteValue:(BOOL)value_;

//- (BOOL)validateFavorite:(id*)value_ error:(NSError**)error_;



- (NSString*)manufacturer;
- (void)setManufacturer:(NSString*)value_;

//- (BOOL)validateManufacturer:(id*)value_ error:(NSError**)error_;



- (NSString*)parentShortName;
- (void)setParentShortName:(NSString*)value_;

//- (BOOL)validateParentShortName:(id*)value_ error:(NSError**)error_;



- (NSString*)shortName;
- (void)setShortName:(NSString*)value_;

//- (BOOL)validateShortName:(id*)value_ error:(NSError**)error_;



- (NSString*)longName;
- (void)setLongName:(NSString*)value_;

//- (BOOL)validateLongName:(id*)value_ error:(NSError**)error_;



- (NSNumber*)auditStatus;
- (void)setAuditStatus:(NSNumber*)value_;

- (int)auditStatusValue;
- (void)setAuditStatusValue:(int)value_;

//- (BOOL)validateAuditStatus:(id*)value_ error:(NSError**)error_;



- (NSString*)auditNotes;
- (void)setAuditNotes:(NSString*)value_;

//- (BOOL)validateAuditNotes:(id*)value_ error:(NSError**)error_;




- (void)addClones:(NSSet*)value_;
- (void)removeClones:(NSSet*)value_;
- (void)addClonesObject:(GameMO*)value_;
- (void)removeClonesObject:(GameMO*)value_;
- (NSMutableSet*)clonesSet;


@end
