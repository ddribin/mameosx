//
//  RomAuditWindowController.m
//  mameosx
//
//  Created by Dave Dribin on 11/27/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "RomAuditWindowController.h"
#import "RomAuditSummary.h"
#include "driver.h"
#include "audit.h"

@implementation RomAuditWindowController

- (id) init
{
    self = [super initWithWindowNibName: @"RomAudit"];
    if (self == nil)
        return nil;
    
    mGameName = nil;
    mStatus = @"";
    mResults = [[NSMutableArray alloc] init];
    
    return self;
}


- (void) awakeFromNib
{    
    [self setStatus: @""];
}

- (void) dealloc
{
    [mGameName release];
    [mStatus release];
    [mResults release];
    [super dealloc];
}

- (NSString *) status;
{
    return mStatus;
}

- (void) setStatus: (NSString *) status;
{
    [status retain];
    [mStatus release];
    mStatus = status;
}

- (void) startCounting
{
    [mProgress setIndeterminate: YES];
    [mProgress startAnimation: self];
}

- (void) startAudit: (NSNumber *) total;
{
    [mProgress setIndeterminate: NO];
    [mProgress setMinValue: 0.0];
    [mProgress setMaxValue: [total intValue]];
    [mProgress setDoubleValue: 0.0];
}

- (void) updateProgress: (NSNumber *) checked;
{
    [mProgress setDoubleValue: [checked intValue]];
}

- (void) auditDone
{
    [mProgress stopAnimation: self];
    [self setStatus: @""];
}

- (void) auditThread
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    FILE * output = stdout;
	int correct = 0;
	int incorrect = 0;
	int checked = 0;
	int notfound = 0;
	int total;
	int drvindex;

    [self willChangeValueForKey: @"results"];
    [mResults removeAllObjects];
    [self didChangeValueForKey: @"results"];

    [self performSelectorOnMainThread: @selector(startCounting)
                           withObject: nil
                        waitUntilDone: NO];

    const char * gamename = [mGameName UTF8String];
	/* first count up how many drivers match the string */
	total = 0;
	for (drvindex = 0; drivers[drvindex]; drvindex++)
		if (!mame_strwildcmp(gamename, drivers[drvindex]->name))
			total++;
    
    [self performSelectorOnMainThread: @selector(startAudit:)
                           withObject: [NSNumber numberWithInt: total]
                        waitUntilDone: NO];

    
	/* now iterate over drivers */
	for (drvindex = 0; drivers[drvindex]; drvindex++)
	{
		audit_record *audit;
		int audit_records;
		int res;
        
		/* skip if we don't match */
		if (mame_strwildcmp(gamename, drivers[drvindex]->name))
			continue;
        
        NSAutoreleasePool * loopPool = [[NSAutoreleasePool alloc] init];

		/* audit the ROMs in this set */
		audit_records = audit_images(drvindex, AUDIT_VALIDATE_FAST, &audit);
        RomAuditSummary * summary =
            [[RomAuditSummary alloc] initWithGameIndex: drvindex
                                           recordCount: audit_records
                                               records: audit];
        [summary autorelease];
        if ([summary status] != NOTFOUND)
        {
#if 1
            [mResults performSelectorOnMainThread: @selector(addObject:)
                                       withObject: summary
                                    waitUntilDone: NO];
#elif 0
            [mResults addObject: summary];
#elif 0
            [mResultsController performSelectorOnMainThread: @selector(addObject:)
                                                 withObject: summary
                                              waitUntilDone: YES];
                
#endif
#if 0
            [mResultsTable performSelectorOnMainThread: @selector(noteNumberOfRowsChanged)
                                            withObject: nil
                                         waitUntilDone: NO];
#endif
        }
#if 0
		res = audit_summary(drvindex, audit_records, audit, NO);
		if (audit_records > 0)
			free(audit);
        
		/* if not found, count that and leave it at that */
		if (res == NOTFOUND)
			notfound++;
        
		/* else display information about what we discovered */
		else
		{
			const game_driver *clone_of;
			clone_of = driver_get_clone(drivers[drvindex]);
            
            if (clone_of == NULL)
            {
                NSString * status = [NSString stringWithFormat:
                    @"ROM set %s...", drivers[drvindex]->name];
                [self performSelectorOnMainThread: @selector(setStatus:)
                                       withObject: status
                                    waitUntilDone: NO];
            }
            else
            {
                NSString * status = [NSString stringWithFormat:
                    @"ROM set %s [%s]...", drivers[drvindex]->name,
                    clone_of->name];
                [self performSelectorOnMainThread: @selector(setStatus:)
                                       withObject: status
                                    waitUntilDone: NO];
            }
            
#if 0
			/* output the name of the driver and its clone */
			fprintf(output, "romset %s ", drivers[drvindex]->name);
			if (clone_of != NULL)
				fprintf(output, "[%s] ", clone_of->name);
#endif
            
			/* switch off of the result */
			switch (res)
			{
				case INCORRECT:
					// fprintf(output, "is bad\n");
					incorrect++;
					break;
                    
				case CORRECT:
					// fprintf(output, "is good\n");
					correct++;
					break;
                    
				case BEST_AVAILABLE:
					// fprintf(output, "is best available\n");
					correct++;
					break;
			}
		}
#endif
        
		/* update progress information on stderr */
		checked++;
		// fprintf(stderr, "%d%%\r", 100 * checked / total);
        
        if ((checked % 10) == 0)
        {
        [self performSelectorOnMainThread: @selector(updateProgress:)
                               withObject: [NSNumber numberWithInt: checked]
                            waitUntilDone: NO];
#if 1
            [mResultsTable performSelectorOnMainThread: @selector(noteNumberOfRowsChanged)
                                            withObject: nil
                                         waitUntilDone: NO];
#elif 0
            [self willChangeValueForKey: @"results"];
            [self didChangeValueForKey: @"results"];
#endif
        }
        
        [loopPool release];
	}
        
    [self performSelectorOnMainThread: @selector(auditDone)
                           withObject: nil
                        waitUntilDone: NO];
    
    [mGameName release];
    mGameName = nil;

    [pool release];
}

- (IBAction) verifyRoms: (id) sender;
{
    mGameName = [@"*" retain];
    [NSThread detachNewThreadSelector: @selector(auditThread)
                             toTarget: self
                           withObject: nil];
}

- (NSMutableArray *) results;
{
    return mResults;
}

-  (void) setResults: (NSMutableArray *) results;
{
    if (mResults != results)
	{
        [mResults autorelease];
        mResults = [results mutableCopy];
    }
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
    id theRecord, theValue;
    
    NSParameterAssert(rowIndex >= 0 && rowIndex < [mResults count]);
    theRecord = [mResults objectAtIndex:rowIndex];
    theValue = [theRecord valueForKey:[aTableColumn identifier]];
    return theValue;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [mResults count];
}

- (void) tableView: (NSTableView *) tableView sortDescriptorsDidChange: (NSArray *) oldDescriptors
{
    NSArray * newDescriptors = [tableView sortDescriptors];
    [mResults sortUsingDescriptors: newDescriptors];
    [tableView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSTextStorage * storage = [mNotesView textStorage];
    int row = [mResultsTable selectedRow];
    NSAttributedString * newText;
    if (row == -1)
    {
        newText = [[NSAttributedString alloc] initWithString: @""];
    }
    else
    {
        NSString * notes = [[mResults objectAtIndex: row] notes];
        newText = [[NSAttributedString alloc] initWithString: notes];
    }
    [storage setAttributedString: newText];
}

@end
