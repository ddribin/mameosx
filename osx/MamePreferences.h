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

- (NSString *) jrLogLevel;
- (void) setJrLogLevel: (NSString *) jrLogLevel;

- (NSString *) windowedZoomLevel;
- (void) setWindowedZoomLevel: (NSString *) windowedZoomLevel;

- (BOOL) fullScreen;
- (void) setFullScreen: (BOOL) fullScreen;

- (BOOL) switchResolutions;
- (void) setSwitchResolutions: (BOOL) switchResolutions;

- (NSString *) fullScreenZoomLevel;
- (void) setFullScreenZoomLevel: (NSString *) fullScreenZoomLevel;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) soundEnabled;
- (void) setSoundEnabled: (BOOL) flag;

- (NSString *) frameRendering;
- (void) setFrameRendering: (NSString *) frameRendering;

- (NSString *) renderingThread;
- (void) setRenderingThread: (NSString *) renderingThread;

- (BOOL) clearToRed;
- (void) setClearToRed: (BOOL) clearToRed;

- (BOOL) linearFilter;
- (void) setLinearFilter: (BOOL) linearFilter;

- (BOOL) smoothFont;
- (void) setSmoothFont: (BOOL) smoothFont;

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

- (NSString *) hardDiskPath;

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

#ifdef MAME_DEBUG
- (BOOL) mameDebug;
#endif

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

- (BOOL) keepAspect;
- (void) setKeepAspect: (BOOL) keepAspect;

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

extern NSString * MameJRLogLevelKey;
extern NSString * MameVersionUrlKey;
extern NSString * MameCheckUpdatesAtStartupKey;
extern NSString * MameGameKey;
extern NSString * MameSleepAtExitKey;
extern NSString * MamePreviousGamesKey;

extern NSString * MameWindowedZoomLevelKey;
extern NSString * MameFullScreenZoomLevelKey;
extern NSString * MameZoomLevelActual;
extern NSString * MameZoomLevelDouble;
extern NSString * MameZoomLevelMaximumIntegral;
extern NSString * MameZoomLevelMaximum;

extern NSString * MameFullScreenKey;
extern NSString * MameSwitchResolutionsKey;
extern NSString * MameFullScreenZoomLevelKey;
extern NSString * MameFullScreenMaximumValue;
extern NSString * MameFullScreenIntegralValue;
extern NSString * MameFullScreenIndependentIntegralValue;
extern NSString * MameFullScreenStretchValue;

extern NSString * MameFrameRenderingKey;
extern NSString * MameRenderFrameInOpenGLValue;
extern NSString * MameRenderFrameInCoreImageValue;
extern NSString * MameFrameRenderingDefaultValue;

extern NSString * MameRenderingThreadKey;
extern NSString * MameRenderInCoreVideoThreadValue;
extern NSString * MameRenderInMameThreadValue;
extern NSString * MameRenderingThreadDefaultValue;

extern NSString * MameThrottledKey;
extern NSString * MameSyncToRefreshKey;
extern NSString * MameSoundEnabledKey;
extern NSString * MameClearToRedKey;
extern NSString * MameLinearFilterKey;
extern NSString * MameSmoothFontKey;

extern NSString * MameRomPath;
extern NSString * MameChdPath;
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

extern NSString * MameKeepAspectKey;

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

