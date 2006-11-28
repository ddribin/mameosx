//
//  RomAuditSummary.h
//  mameosx
//
//  Created by Dave Dribin on 11/27/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "audit.h"


@interface RomAuditSummary : NSObject {
    NSString * mGameName;
    NSString * mCloneName;
    NSString * mDescription;
    int mStatus;
    NSString * mNotes;
}

// int audit_summary(int game, int count, const audit_record *records, int output)

- (id) initWithGameIndex: (int) game
             recordCount: (int) count
                 records: (const audit_record *) records;

- (NSString *) gameName;

- (NSString *) cloneName;

- (NSString *) description;

- (int) status;

- (NSString *) statusString;

- (NSString *) notes;

@end
