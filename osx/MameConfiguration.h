//
//  MameConfiguration.h
//  mameosx
//
//  Created by Dave Dribin on 9/13/06.
//

#import <Cocoa/Cocoa.h>


@interface MameConfiguration : NSObject
{
    BOOL mThrottled;
    BOOL mSyncToRefresh;
    BOOL mSoundEnabled;
    
    char * mRomPath;
    char * mSaveGame;
    char * mBios;
}

+ (MameConfiguration *) globalConfiguration;

- (void) loadUserDefaults;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) soundEnabled;
- (void) setSoundEnabled: (BOOL) flag;

- (const char *) romPath;
- (void) setRomPath: (const char *) newRomPath;

- (const char *) saveGame;
- (void) setSaveGame: (const char *) newSaveGame;

- (const char *) bios;
- (void) setBios: (const char *) newBios;



@end
