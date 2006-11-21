//
//  MamePreferences.h
//  mameosx
//
//  Created by Dave Dribin on 11/21/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MamePreferences : NSObject
{
    NSUserDefaults * mDefaults;
}

+ (MamePreferences *) standardPreferences;

- (id) init;

- (id) initWithUserDefaults: (NSUserDefaults *) userDefaults;

#pragma mark -
#pragma mark MAME OS X Options

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) soundEnabled;
- (void) setSoundEnabled: (BOOL) flag;

- (BOOL) renderInCV;
- (void) setRenderInCV: (BOOL) flag;

- (BOOL) clearToRed;
- (void) setClearToRed: (BOOL) clearToRed;

@end

extern NSString * MameThrottledKey;
extern NSString * MameSyncToRefreshKey;
extern NSString * MameSoundEnabledKey;
extern NSString * MameRenderInCVKey;
extern NSString * MameClearToRedKey;
