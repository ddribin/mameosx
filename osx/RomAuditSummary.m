//
//  RomAuditSummary.m
//  mameosx
//
//  Created by Dave Dribin on 11/27/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "RomAuditSummary.h"
#include "driver.h"

@implementation RomAuditSummary

- (id) init;
{
    NSLog(@"init");
    return [self initWithGameIndex: 0 recordCount: 0 records: NULL];
}

- (id) initWithGameIndex: (int) game
             recordCount: (int) count
                 records: (const audit_record *) records;
{
    self = [super init];
    if (self == nil)
        return nil;

	const game_driver *gamedrv = drivers[game];
    const game_driver *clone_of = driver_get_clone(drivers[game]);
    
    mGameName = [[NSString alloc] initWithUTF8String: gamedrv->name];
    if (clone_of != NULL)
        mCloneName = [[NSString alloc] initWithUTF8String: clone_of->name];
    else
        mCloneName = @"";
    mDescription = [[NSString alloc] initWithUTF8String: gamedrv->description];
    
	/* no count or records means not found */
	if (count == 0 || records == NULL)
    {
        mStatus = NOTFOUND;
		return self;
    }

	int overall_status = CORRECT;
	int notfound = 0;
	int recnum;
    BOOL output = YES;
    
    NSMutableString * notes = [NSMutableString string];
    
	/* loop over records */
	for (recnum = 0; recnum < count; recnum++)
	{
		const audit_record *record = &records[recnum];
		int best_new_status = INCORRECT;
        
		/* skip anything that's fine */
		if (record->substatus == SUBSTATUS_GOOD)
			continue;
        
		/* count the number of missing items */
		if (record->status == AUDIT_STATUS_NOT_FOUND)
			notfound++;
        
		/* output the game name, file name, and length (if applicable) */
		if (output)
		{
			[notes appendFormat: @"%s", record->name];
			if (record->explength > 0)
				[notes appendFormat: @" (%d bytes)", record->explength];
			[notes appendFormat: @" - "];
		}
        
		/* use the substatus for finer details */
		switch (record->substatus)
		{
			case SUBSTATUS_GOOD_NEEDS_REDUMP:
				if (output) [notes appendString: @"NEEDS REDUMP\n"];
				best_new_status = BEST_AVAILABLE;
				break;
                
			case SUBSTATUS_FOUND_NODUMP:
				if (output) [notes appendString: @"NO GOOD DUMP KNOWN\n"];
				best_new_status = BEST_AVAILABLE;
				break;
                
			case SUBSTATUS_FOUND_BAD_CHECKSUM:
				if (output)
				{
#if 0
					char hashbuf[512];
                    
					mame_printf_info("INCORRECT CHECKSUM:\n");
					hash_data_print(record->exphash, 0, hashbuf);
					mame_printf_info("EXPECTED: %s\n", hashbuf);
					hash_data_print(record->hash, 0, hashbuf);
					mame_printf_info("   FOUND: %s\n", hashbuf);
#endif
				}
				break;
                
			case SUBSTATUS_FOUND_WRONG_LENGTH:
				if (output) [notes appendFormat: @"INCORRECT LENGTH: %d bytes\n", record->length];
				break;
                
			case SUBSTATUS_NOT_FOUND:
				if (output) [notes appendFormat: @"NOT FOUND\n"];
				break;
                
			case SUBSTATUS_NOT_FOUND_NODUMP:
				if (output) [notes appendFormat: @"NOT FOUND - NO GOOD DUMP KNOWN\n"];
				best_new_status = BEST_AVAILABLE;
				break;
                
			case SUBSTATUS_NOT_FOUND_OPTIONAL:
				if (output) [notes appendFormat: @"NOT FOUND BUT OPTIONAL\n"];
				best_new_status = BEST_AVAILABLE;
				break;
                
			case SUBSTATUS_NOT_FOUND_PARENT:
				if (output) [notes appendFormat: @"NOT FOUND (shared with parent)\n"];
				break;
                
			case SUBSTATUS_NOT_FOUND_BIOS:
				if (output) [notes appendFormat: @"NOT FOUND (BIOS)\n"];
				break;
		}
        
		/* downgrade the overall status if necessary */
		overall_status = MAX(overall_status, best_new_status);
	}
    
	mStatus = (notfound == count) ? NOTFOUND : overall_status;
    mNotes = [notes copy];

    return self;
}

- (void) dealloc
{
    [mGameName release];
    [mCloneName release];
    [mDescription release];
    [mNotes release];
    [super dealloc];
}

- (NSString *) gameName;
{
    return mGameName;
}

- (NSString *) cloneName;
{
    return mCloneName;
}

- (NSString *) description;
{
    return mDescription;
}

- (int) status;
{
    return mStatus;
}

- (NSString *) statusString;
{
    switch (mStatus)
    {
        case INCORRECT:
            return @"Bad";
            
        case CORRECT:
            return @"Good";
            
        case BEST_AVAILABLE:
            return @"Best Available";
            
        default:
            return @"N/A";
    }
}

- (NSString *) notes;
{
    return mNotes;
}

@end
