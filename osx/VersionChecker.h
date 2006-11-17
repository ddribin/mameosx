/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>


@interface VersionChecker : NSObject
{
    BOOL mUpdateInProgress;
    NSString * mVersionUrl;
    BOOL mVerbose;
    
    // Transient values, only valid while update in progress
    NSString * mMyVersion;
    NSString * mMyVersionString;
    NSString * mCurrentVersion;
    NSString * mCurrentVersionString;
    NSString * mDownloadUrl;
    NSString * mInfoUrl;
}

- (NSString *) versionUrl;
- (void) setVersionUrl: (NSString *)value;

- (BOOL) updateInProgress;

- (IBAction) checkForUpdates: (id) sender;
- (void) checkForUpdatesInBackground;
- (void) checkForUpdatesAndNotify: (BOOL) notify;

@end
