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

@class MameConfiguration;

@interface MamePreferences : NSObject
{
    NSUserDefaults * mDefaults;
}

+ (MamePreferences *) standardPreferences;

- (id) init;

- (id) initWithUserDefaults: (NSUserDefaults *) userDefaults;

#pragma mark -
#pragma mark User defaults

- (void) registerDefaults;

- (void) synchronize;

#pragma mark -
#pragma mark MAME OS X Options

- (NSString *) nxLogLevel;
- (void) setNxLogLevel: (NSString *) nxLogLevel;

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

- (BOOL) linearFilter;
- (void) setLinearFilter: (BOOL) linearFilter;

- (BOOL) checkUpdatesAtStartup;

- (NSArray *) previousGames;
- (void) setPreviousGames: (NSArray *) previousGames;

#pragma mark -
#pragma mark Private MAME OS X Options

- (NSString *) versionUrl;

- (NSString *) game;

- (BOOL) sleepAtExit;

#pragma mark -
#pragma mark Directories and paths

- (NSString *) romPath;

- (NSString *) samplePath;

- (NSString *) artworkPath;

- (NSString *) diffDirectory;

- (NSString *) nvramDirectory;

- (NSString *) configDirectory;

- (NSString *) inputDirectory;

- (NSString *) stateDirectory;

- (NSString *) memcardDirectory;

- (NSString *) snapshotDirectory;

- (NSString *) ctrlrPath;

- (NSString *) commentDirectory;

#pragma mark -

- (BOOL) mameDebug;

- (BOOL) cheat;

#pragma mark -
#pragma mark Messages

- (BOOL) skipDisclaimer;

- (BOOL) skipGameInfo;

- (BOOL) skipWarnings;

#pragma mark -
#pragma mark Sound

- (int) sampleRate;

- (BOOL) useSamples;

#pragma mark -
#pragma mark Graphics

- (float) brightness;

- (float) contrast;

- (float) gamma;

- (float) pauseBrightness;

#pragma mark -
#pragma mark Vector

- (float) beamWidth;

- (BOOL) antialiasBeam;

- (BOOL) vectorFlicker;

#pragma mark -

- (NSString *) saveGame;

- (BOOL) autoSave;

- (NSString *) bios;

#pragma mark -
#pragma mark Integration with MAME options

- (void) copyToMameConfiguration: (MameConfiguration *) configuration;

@end

#pragma mark -
#pragma mark Preference Keys

extern NSString * MameNXLogLevelKey;
extern NSString * MameVersionUrlKey;
extern NSString * MameCheckUpdatesAtStartupKey;
extern NSString * MameGameKey;
extern NSString * MameSleepAtExitKey;
extern NSString * MamePreviousGamesKey;


extern NSString * MameThrottledKey;
extern NSString * MameSyncToRefreshKey;
extern NSString * MameSoundEnabledKey;
extern NSString * MameRenderInCVKey;
extern NSString * MameClearToRedKey;
extern NSString * MameLinearFilterKey;

extern NSString * MameRomPath;
extern NSString * MameSamplePath;
extern NSString * MameConfigPath;
extern NSString * MameNvramPath;
extern NSString * MameMemcardPath;
extern NSString * MameInputPath;
extern NSString * MameHighScorePath;
extern NSString * MameStatePath;
extern NSString * MameArtworkPath;
extern NSString * MameSnapshotPath;
extern NSString * MameDiffPath;
extern NSString * MameCtrlrPath;
extern NSString * MameCommentPath;
extern NSString * MameCheatPath;

#ifdef MAME_DEBUG
extern NSString * MameDebugKey;
#endif
extern NSString * MameCheatKey;
extern NSString * MameSkipDisclaimerKey;
extern NSString * MameSkipGameInfoKey;
extern NSString * MameSkipWarningsKey;

extern NSString * MameSampleRateKey;
extern NSString * MameUseSamplesKey;

extern NSString * MameBrightnessKey;
extern NSString * MameContrastKey;
extern NSString * MameGammaKey;
extern NSString * MamePauseBrightnessKey;

extern NSString * MameBeamWidthKey;
extern NSString * MameVectorFlickerKey;
extern NSString * MameAntialiasBeamKey;

extern NSString * MameSaveGameKey;
extern NSString * MameAutosaveKey;
extern NSString * MameBiosKey;

