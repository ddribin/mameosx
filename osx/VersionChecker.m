/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import "VersionChecker.h"

@interface VersionChecker (Private)

- (void) setUpdateInProgress: (BOOL) updateInProgress;

- (void) downloadVersionInBackground: (NSString *) versionUrl;

- (void) downloadVersionFailedForUrl: (NSString *) versionUrl;

- (void) downloadVersionComplete: (NSDictionary *) versionDictionary;

- (void) displayNewVersionAvailableDialog;

- (void) displayUpToDateDialog;

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
    NSBundle * myBundle = [NSBundle mainBundle];
    NSString * myId = [myBundle bundleIdentifier];
    NSDictionary * infoDict = [myBundle infoDictionary];
    mMyVersion = [infoDict valueForKey:@"CFBundleVersion"];
    mMyVersionString = [infoDict valueForKey:@"CFBundleShortVersionString"];
    
    NSDictionary * versionDict = [versionDictionary valueForKey: myId];
    mCurrentVersion = [versionDict valueForKey:@"version"];
    mCurrentVersionString = [versionDict valueForKey:@"versionString"];
    mDownloadUrl = [versionDict valueForKey:@"downloadUrl"];
    mInfoUrl = [versionDict valueForKey:@"infoUrl"];

    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * skippedVersion = [defaults stringForKey: @"SkippedVersion"];
    
    NSLog([NSString stringWithFormat:@"%@: my version: %@, current version: %@, skipped version: %@",
        myId, mMyVersion, mCurrentVersion, skippedVersion]);
    
    if (![mMyVersion isEqualToString: mCurrentVersion])
    {
        if (![skippedVersion isEqualToString: mCurrentVersion] || mVerbose)
        {
            [self displayNewVersionAvailableDialog];
        }
    }
    else if (mVerbose)
    {
        [self displayUpToDateDialog];
    }
    [self setUpdateInProgress: NO];
}

- (void) displayNewVersionAvailableDialog;
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSString * message = [NSString stringWithFormat:
        @"MAME OS X %@ is available (you have %@).  "
        @"Would you like to download it now?",
        mCurrentVersionString, mMyVersionString];
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
        [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: mDownloadUrl]];
    }
    else if (result == NSAlertSecondButtonReturn)
    {
        [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: mInfoUrl]];
    }
    else if (result == NSAlertThirdButtonReturn)
    {
        [defaults setObject: mCurrentVersion forKey: @"SkippedVersion"];
    }
    else if (result == NSAlertThirdButtonReturn + 1)
    {
        [defaults setObject: nil forKey: @"SkippedVersion"];
    }
    [defaults synchronize];
    [alert release];
}

- (void) displayUpToDateDialog;
{
    NSString * message = [NSString stringWithFormat:
        @"Version %@ of MAME OS X is the most current version.",
        mCurrentVersionString];
    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText: @"Your version of MAME OS X is up to date."];
    [alert setInformativeText: message];
    [alert setAlertStyle: NSInformationalAlertStyle];
    [alert addButtonWithTitle: @"OK"];
    [alert runModal];
    [alert release];
}


@end
