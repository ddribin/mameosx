//
//  VersionChecker.h
//  mameosx
//
//  Created by Dave Dribin on 11/15/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

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
