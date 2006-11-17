/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

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

