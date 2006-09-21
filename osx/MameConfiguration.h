//
//  MameConfiguration.h
//  mameosx
//
//  Created by Dave Dribin on 9/13/06.
//

#import <Cocoa/Cocoa.h>


@class MameController;

@interface MameConfiguration : NSObject
{
    MameController * mController;
    BOOL mThrottled;
    BOOL mSyncToRefresh;
    BOOL mSoundEnabled;
    
    char * mSaveGame;
    char * mBios;
}

- (id) initWithController: (MameController *) controller;

- (void) loadUserDefaults;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) soundEnabled;
- (void) setSoundEnabled: (BOOL) flag;

- (const char *) saveGame;
- (void) setSaveGame: (const char *) newSaveGame;

- (const char *) bios;
- (void) setBios: (const char *) newBios;



@end
