//
//  VersionChecker.m
//  mameosx
//
//  Created by Dave Dribin on 11/15/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VersionChecker.h"

@interface VersionChecker (Private)

- (void) setUpdateInProgress: (BOOL) updateInProgress;

- (void) downloadVersionInBackground: (NSString *) versionUrl;

- (void) downloadVersionFailedForUrl: (NSString *) versionUrl;

- (void) downloadVersionComplete: (NSDictionary *) versionDictionary;

@end


@implementation VersionChecker

- (id) init;
{
    if ([super init] == nil)
        return nil;
    
    mUpdateInProgress = NO;
    mVerbose = NO;
   
    return self;
}

- (NSString *) versionUrl;
{
    return mVersionUrl;
}

- (void) setVersionUrl: (NSString *) versionUrl;
{
    [versionUrl retain];
    [mVersionUrl release];
    mVersionUrl = versionUrl;
}

- (BOOL) updateInProgress;
{
    return mUpdateInProgress;
}

- (IBAction) checkForUpdates: (id) sender;
{
    [self checkForUpdatesAndNotify: YES];
}

- (void) checkForUpdatesInBackground;
{
    [self checkForUpdatesAndNotify: NO];
}

- (void) checkForUpdatesAndNotify: (BOOL) notify;
{
    if (mUpdateInProgress == YES)
    {
        NSLog(@"Update already in progress");
        return;
    }
    
    [self setUpdateInProgress: YES];
    mVerbose = notify;
	[NSThread detachNewThreadSelector :@selector(downloadVersionInBackground:)
                             toTarget: self withObject: mVersionUrl];
}

@end

@implementation VersionChecker (Private)

- (void) setUpdateInProgress: (BOOL) updateInProgress;
{
    mUpdateInProgress = updateInProgress;
}

- (void) downloadVersionInBackground: (NSString *) versionUrl;
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    NSDictionary * plist = [[NSDictionary alloc] initWithContentsOfURL:
        [NSURL URLWithString: versionUrl]];
    if (!plist)
    {
        [self performSelectorOnMainThread: @selector(downloadVersionFailedForUrl:)
                               withObject: versionUrl
                            waitUntilDone: NO];
    }
    else
    {
        [self performSelectorOnMainThread: @selector(downloadVersionComplete:)
                               withObject: plist
                            waitUntilDone: NO];
    }
    
    [pool release];
}
    

- (void) downloadVersionFailedForUrl: (NSString *) versionUrl;
{
    if (mVerbose)
    {
        NSAlert * alert = [[NSAlert alloc] init];
        [alert setMessageText: @"Could not get version information."];
        [alert setInformativeText:
            @"An error occured while trying to retrieve the current version."];
        [alert setAlertStyle: NSWarningAlertStyle];
        [alert addButtonWithTitle: @"OK"];
        [alert runModal];
        [alert release];
    }
    NSLog(@"Couldn't access version info");
    NSLog(@"versionUrl: %@", versionUrl);
    [self setUpdateInProgress: NO];
    return;
}

- (void) downloadVersionComplete: (NSDictionary *) versionDictionary;
{
    [versionDictionary autorelease];
    NSBundle *app = [NSBundle mainBundle];
    NSString *ident = [app bundleIdentifier];
    NSDictionary *infoDict = [app infoDictionary];
    NSString *myVersion = (NSString *)[infoDict valueForKey:@"CFBundleVersion"];
    NSString *myVersionString = (NSString *)[infoDict valueForKey:@"CFBundleShortVersionString"];
    
    NSDictionary * versionDict = (NSDictionary *)[versionDictionary valueForKey:ident];
    NSString * currentVersion = (NSString *)[versionDict valueForKey:@"version"];
    NSString * currentVersionString = (NSString *)[versionDict valueForKey:@"versionString"];
    NSString * downloadUrl = (NSString *)[versionDict valueForKey:@"downloadUrl"];
    NSString * infoUrl = (NSString *)[versionDict valueForKey:@"infoUrl"];
    
    NSLog([NSString stringWithFormat:@"%@: my version: %@, current version:s %@",
        ident, myVersion, currentVersion]);
    
    if (![myVersion isEqualToString:currentVersion])
    {
        NSString * message = [NSString stringWithFormat:
            @"MAME OS X %@ is available (you have %@).  Would you like to download it now?", currentVersionString, myVersionString];
        NSAlert * alert = [[NSAlert alloc] init];
        [alert setMessageText: @"A new version of MAME OS X is available."];
        [alert setInformativeText: message];
        [alert setAlertStyle: NSInformationalAlertStyle];
        [alert addButtonWithTitle: @"Download..."];
        [alert addButtonWithTitle: @"More info..."];
        [alert addButtonWithTitle: @"Skip this version"];
        [alert addButtonWithTitle: @"Remind later"];
        int result = [alert runModal];
        if (result == NSAlertFirstButtonReturn)
        {
            [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: downloadUrl]];
        }
        else if (result == NSAlertSecondButtonReturn)
        {
            [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: infoUrl]];
        }
        [alert release];
    }
    else if (mVerbose)
    {
        NSString * message = [NSString stringWithFormat:
            @"Version %@ of MAME OS X is the most current version.",
            currentVersionString];
        NSAlert * alert = [[NSAlert alloc] init];
        [alert setMessageText: @"Your version of MAME OS X is up to date."];
        [alert setInformativeText: message];
        [alert setAlertStyle: NSInformationalAlertStyle];
        [alert addButtonWithTitle: @"OK"];
        [alert runModal];
        [alert release];
    }
    [self setUpdateInProgress: NO];
}

@end
