//
//  MameConfiguration.h
//  mameosx
//
//  Created by Dave Dribin on 9/13/06.
//

#import <Cocoa/Cocoa.h>


@class MameFileManager;

@interface MameConfiguration : NSObject
{
    MameFileManager * mFileManager;
    BOOL mThrottled;
    BOOL mSyncToRefresh;
    BOOL mSoundEnabled;
    BOOL mRenderInCV;
    BOOL mClearToRed;
    
    char * mSaveGame;
    char * mBios;
}

- (MameFileManager *) fileManager;
- (void) setFileManager: (MameFileManager *) theFileManager;

- (void) loadUserDefaults;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) renderInCV;
- (void) setRenderInCV: (BOOL) flag;

- (BOOL) clearToRed;
- (void) setClearToRed: (BOOL) clearToRed;

- (BOOL) soundEnabled;
- (void) setSoundEnabled: (BOOL) flag;

- (const char *) saveGame;
- (void) setSaveGame: (const char *) newSaveGame;

- (const char *) bios;
- (void) setBios: (const char *) newBios;

@end

extern NSString * MameVersionUrl;
extern NSString * MameRomPath;
extern NSString * MameSamplePath;
extern NSString * MameArtworkPath;

