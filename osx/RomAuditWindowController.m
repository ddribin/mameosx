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

@interface RomAuditWindowController (Private)

- (void) setStatus: (NSString *) status;
- (void) updatePredicate;

@end

@implementation RomAuditWindowController

- (id) init
{
    self = [super initWithWindowNibName: @"RomAudit"];
    if (self == nil)
        return nil;
    
    mGameName = @"";
    mStatus = @"";
    mShowGood = NO;
    mResults = [[NSMutableArray alloc] init];
    
    return self;
}


- (void) awakeFromNib
{
    // Avoid a memory leak.  See steps here, plus "Step 4":
    // http://theobroma.treehouseideas.com/document.page/18
    // Or:
    // http://www.cocoabuilder.com/archive/message/cocoa/2006/10/24/173255
    [mControllerAlias setContent: self];
    
    [self setStatus: @""];
    [self updatePredicate];
}

- (void) dealloc
{
    [mGameName release];
    [mStatus release];
    [mSearchString release];
    [mResults release];
    [super dealloc];
}

- (void) windowWillClose: (NSNotification *) notification
{
    [mControllerAlias setContent: nil];
}

- (NSString *) status;
{
    return mStatus;
}

- (NSString *) gameName;
{
    return mGameName;
}

- (void) setGameName: (NSString *) gameName;
{
    [gameName retain];
    [mGameName release];
    mGameName = gameName;
}

- (NSString *) searchString;
{
    return mSearchString;
}

- (void) setSearchString: (NSString *) searchString;
{
    [searchString retain];
    [mSearchString release];
    mSearchString = searchString;
    [self updatePredicate];
}

- (BOOL) showGood;
{
    return mShowGood;
}

- (void) setShowGood: (BOOL) showGood;
{
    mShowGood = showGood;
    [self updatePredicate];
}

- (void) updateProgress: (NSNumber *) checked;
{
    [mProgress setDoubleValue: [checked doubleValue]];
}

- (void) auditDone: (NSMutableArray *) results
{
    [self setStatus: @""];

    [self setResults: results];

    [NSApp abortModal];
}

- (void) auditThread: (NSString *) gameName;
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    FILE * output = stdout;
	int correct = 0;
	int incorrect = 0;
	int checked = 0;
	int notfound = 0;
	int total;
	int drvindex;

    const char * gameNameUtf8 = [gameName UTF8String];
	/* first count up how many drivers match the string */
	total = 0;
	for (drvindex = 0; drivers[drvindex]; drvindex++)
		if (!mame_strwildcmp(gameNameUtf8, drivers[drvindex]->name))
			total++;
    
    NSMutableArray * results = [NSMutableArray arrayWithCapacity: total];
    
    double totalf = total; 
    double lastProgressValuef = 0.0;
	/* now iterate over drivers */
	for (drvindex = 0; drivers[drvindex]; drvindex++)
	{
		audit_record * auditRecords;
		int recordCount;
		int res;
        
        if (!mRunning)
            break;
        
		/* skip if we don't match */
		if (mame_strwildcmp(gameNameUtf8, drivers[drvindex]->name))
			continue;
        
        NSAutoreleasePool * loopPool = [[NSAutoreleasePool alloc] init];

		/* audit the ROMs in this set */
		recordCount = audit_images(drvindex, AUDIT_VALIDATE_FAST, &auditRecords);
        RomAuditSummary * summary =
            [[RomAuditSummary alloc] initWithGameIndex: drvindex
                                           recordCount: recordCount
                                               records: auditRecords];
        [summary autorelease];
        free(auditRecords);

        if ([summary status] != NOTFOUND)
        {
            [results addObject: summary];
        }
        
		checked++;
        
        // Stolen from:
        // http://www.cocoabuilder.com/archive/message/cocoa/2006/8/24/170090
        double checkedf = checked;
        int percentAsInt = (checkedf/totalf)*200.0;
        double modifiedProgressValuef = percentAsInt/200.0;
        
        // do your work, then...
        if (modifiedProgressValuef != lastProgressValuef)
        {
            [self willChangeValueForKey: @"currentProgress"];
            mCurrentProgress = modifiedProgressValuef;
            [self didChangeValueForKey: @"currentProgress"];
            lastProgressValuef = modifiedProgressValuef;

            NSString * status = [NSString stringWithFormat:
                @"Checking %d of %d", checked, total];
            [self setStatus: status];
        }

        [loopPool release];
	}
    [self performSelectorOnMainThread: @selector(auditDone:)
                           withObject: results
                        waitUntilDone: NO];

    [pool release];
}

- (double) currentProgress;
{
    return mCurrentProgress;
}

- (void) setCurrentProgress: (double) currentProgress
{
    mCurrentProgress = currentProgress;
}

- (IBAction) verifyRoms: (id) sender;
{
    [mProgress setDoubleValue: 0.0];
    [NSApp beginSheet: mProgressPanel
       modalForWindow: [self window]
        modalDelegate: nil
       didEndSelector: nil
          contextInfo: nil];

    mRunning = YES;

    NSString * gameName;
    if (mGameName == nil)
        gameName = @"*";
    else
        gameName = [[mGameName copy] autorelease];
    [NSThread detachNewThreadSelector: @selector(auditThread:)
                             toTarget: self
                           withObject: gameName];
   
    [NSApp runModalForWindow: mProgressPanel];
    [NSApp endSheet: mProgressPanel];
    [mProgressPanel orderOut: self];
}

- (IBAction) cancel: (id) sender;
{
    mRunning = NO;
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


@end

@implementation RomAuditWindowController (Private)


- (void) setStatus: (NSString *) status;
{
    [status retain];
    [mStatus release];
    mStatus = status;
}

- (void) updatePredicate;
{
    NSPredicate * predicate;
    if (mSearchString != nil)
    {
        if (mShowGood) {
        predicate = [NSPredicate predicateWithFormat:
            @"gameName contains[c] %@ OR description contains[c] %@",
            mSearchString, mSearchString];
        }
        else
        {
            predicate = [NSPredicate predicateWithFormat:
                @"(gameName contains[c] %@ OR description contains[c] %@) and status != 0",
                mSearchString, mSearchString];
        }
    }
    else
    {
        if (mShowGood)
            predicate = nil;
        else
        {
            predicate = [NSPredicate predicateWithFormat: @"status != 0"];
        }
    }
    [mResultsController setFilterPredicate: predicate];
}

@end

