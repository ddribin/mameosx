/*
 * Copyright (c) 2006 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
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
extern NSString * MameThrottledKey;
extern NSString * MameSyncToRefreshKey;


