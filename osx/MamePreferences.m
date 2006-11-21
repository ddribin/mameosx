//
//  MamePreferences.m
//  mameosx
//
//  Created by Dave Dribin on 11/21/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MamePreferences.h"


static MamePreferences * sInstance;

#if 0
NSString * MameThrottledKey = @"Throttled";
NSString * MameSyncToRefreshKey = @"SyncToRefresh";
NSString * MameSoundEnabledKey = @"SoundEnabled";
NSString * MameRenderInCVKey = @"RenderInCV";
NSString * MameClearToRedKey = @"ClearToRed";
#endif

@implementation MamePreferences

#pragma mark Init and dealloc

+ (MamePreferences *) standardPreferences;
{
    if (sInstance == nil)
        sInstance = [[MamePreferences alloc] init];
    
    return sInstance;
}

- (id) init;
{
    return [self initWithUserDefaults: [NSUserDefaults standardUserDefaults]];
}

- (id) initWithUserDefaults: (NSUserDefaults *) userDefaults;
{
    self = [super init];
    if (self == nil)
        return nil;
   
    mDefaults = [userDefaults retain];

    return self;
}

- (void) dealloc
{
    [mDefaults release];
    [super dealloc];
}

#pragma mark -
#pragma mark MAME OS X Options

//=========================================================== 
//  throttled 
//=========================================================== 
- (BOOL) throttled
{
    return [mDefaults boolForKey: MameThrottledKey];
}

- (void) setThrottled: (BOOL) flag
{
    [mDefaults setBool: flag forKey:MameThrottledKey];
}

//=========================================================== 
//  syncToRefresh 
//=========================================================== 
- (BOOL) syncToRefresh;
{
    return [mDefaults boolForKey: MameSyncToRefreshKey];
}

- (void) setSyncToRefresh: (BOOL) flag;
{
    [mDefaults setBool: flag forKey:MameSyncToRefreshKey];
}

//=========================================================== 
//  soundEnabled 
//=========================================================== 
- (BOOL) soundEnabled;
{
    return [mDefaults boolForKey: MameSoundEnabledKey];
}

- (void) setSoundEnabled: (BOOL) flag;
{
    [mDefaults setBool: flag forKey: MameSoundEnabledKey];
}

//=========================================================== 
//  renderInCV 
//=========================================================== 
- (BOOL) renderInCV
{
    return [mDefaults boolForKey: MameRenderInCVKey];
}

- (void) setRenderInCV: (BOOL) flag
{
    [mDefaults setBool: flag forKey: MameRenderInCVKey];
}

//=========================================================== 
//  clearToRed 
//=========================================================== 
- (BOOL) clearToRed;
{
    return [mDefaults boolForKey: MameClearToRedKey];
}

- (void) setClearToRed: (BOOL) clearToRed;
{
    [mDefaults setBool: clearToRed forKey: MameClearToRedKey];
}

@end
