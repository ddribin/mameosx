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

#import "MameConfiguration.h"
#import "MameController.h"
#import "MameFileManager.h"
#include "mame.h"
#include <mach/mach_host.h>
#include <mach/host_info.h>

@interface MameConfiguration (Private)

+ (void) initializeDefaultPaths: (NSMutableDictionary *) defaultValues;
- (void) loadDefaultPaths: (NSUserDefaults *) defaults;

@end

@implementation MameConfiguration

NSString * MameVersionUrlKey = @"VersionUrl";
NSString * MameCheckUpdatesAtStartupKey = @"CheckUpdatesAtStartup";

NSString * MameRomPath = @"RomPath";
NSString * MameSamplePath = @"SamplePath";
NSString * MameConfigPath = @"ConfigPath";
NSString * MameNvramPath = @"NvramPath";
NSString * MameMemcardPath = @"MemcardPath";
NSString * MameInputPath = @"InputPath";
NSString * MameHighScorePath = @"HighScorePath";
NSString * MameStatePath = @"StatePath";
NSString * MameArtworkPath = @"ArtworkPath";
NSString * MameSnapshotPath = @"SnapshotPath";
NSString * MameDiffPath = @"DiffPath";
NSString * MameCtrlrPath = @"CtrlrPath";
NSString * MameCommentPath = @"CommentPath";
NSString * MameCheatPath = @"CheatPath";

NSString * MameThrottledKey = @"Throttled";
NSString * MameSyncToRefreshKey = @"SyncToRefresh";
NSString * MameSoundEnabled = @"SoundEnabled";
NSString * MameRenderInCV = @"RenderInCV";
NSString * MameClearToRed = @"ClearToRed";

#ifdef MAME_DEBUG
NSString * MameDebugKey = @"MameDebug";
#endif
NSString * MameCheatKey = @"Cheat";
NSString * MameSkipDisclaimerKey = @"SkipDisclaimer";
NSString * MameSkipGameInfoKey = @"SkipGameInfo";
NSString * MameSkipWarningsKey = @"SkipWarnings";

NSString * MameSampleRateKey = @"SampleRate";
NSString * MameUseSamplesKey = @"UseSamples";

NSString * MameBrightnessKey = @"Brightness";
NSString * MameContrastKey = @"Contrast";
NSString * MameGammaKey = @"Gamma";
NSString * MamePauseBrightnessKey = @"PauseBrightness";

NSString * MameBeamWidthKey = @"BeamWidth";
NSString * MameVectorFlickerKey = @"VectorFlicker";
NSString * MameAntialiasBeamKey = @"AntialiasBeam";

NSString * MameSaveGameKey = @"SaveGame";
NSString * MameAutosaveKey = @"AutoSave";
NSString * MameBiosKey = @"Bios";

NSString * MameDebugWidthKey = @"DebugWidth";
NSString * MameDebugHeightKey = @"DebugHeight";
NSString * MameDebugDepthKey = @"DebugDepth";


static BOOL hasMultipleCPUs()
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	host_info(mach_host_self(), HOST_BASIC_INFO, 
			  (host_info_t)&hostInfo, &infoCount);
    if (hostInfo.avail_cpus > 1)
        return YES;
    else
        return NO;
}

+ (void) initialize
{
    NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
    
    [defaultValues setObject: @"http://mameosx.sourceforge.net/version.plist"
                      forKey: MameVersionUrlKey];

    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameCheckUpdatesAtStartupKey];
    
    [self initializeDefaultPaths: defaultValues];

    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameThrottledKey];
    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameSyncToRefreshKey];

    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameSoundEnabled];

    if (hasMultipleCPUs())
    {
        [defaultValues setObject: [NSNumber numberWithBool: YES]
                          forKey: MameRenderInCV];
    }
    else
    {
        [defaultValues setObject: [NSNumber numberWithBool: NO]
                          forKey: MameRenderInCV];
    }
    
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameClearToRed];
    
#ifdef MAME_DEBUG
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameDebugKey];
#endif
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameCheatKey];
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameSkipDisclaimerKey];
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameSkipGameInfoKey];
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameSkipWarningsKey];
    
    [defaultValues setObject: [NSNumber numberWithInt: 48000]
                      forKey: MameSampleRateKey];
    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameUseSamplesKey];
    
    [defaultValues setObject: [NSNumber numberWithFloat: 1.0f]
                      forKey: MameBrightnessKey];
    [defaultValues setObject: [NSNumber numberWithFloat: 1.0f]
                      forKey: MameContrastKey];
    [defaultValues setObject: [NSNumber numberWithFloat: 1.0f]
                      forKey: MameGammaKey];
    [defaultValues setObject: [NSNumber numberWithFloat: 0.65f]
                      forKey: MamePauseBrightnessKey];
    
    [defaultValues setObject: [NSNumber numberWithFloat: 1.1f]
                      forKey: MameBeamWidthKey];
    [defaultValues setObject: [NSNumber numberWithFloat: 1.0f]
                      forKey: MameVectorFlickerKey];
    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameAntialiasBeamKey];
    
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameAutosaveKey];
    [defaultValues setObject: @"default"
                      forKey: MameBiosKey];
    
    [defaultValues setObject: [NSNumber numberWithInt: 640]
                      forKey: MameDebugWidthKey];
    [defaultValues setObject: [NSNumber numberWithInt: 480]
                      forKey: MameDebugHeightKey];
    [defaultValues setObject: [NSNumber numberWithInt: 8]
                      forKey: MameDebugDepthKey];
    
    [[NSUserDefaults standardUserDefaults]
        registerDefaults: defaultValues];
}

static MameConfiguration * sGlobalConfiguration = nil;

+ (MameConfiguration *) globalConfiguration;
{
    if (sGlobalConfiguration == nil)
        sGlobalConfiguration = [[MameConfiguration alloc] init];
    return sGlobalConfiguration;
}

//=========================================================== 
//  fileManager 
//=========================================================== 
- (MameFileManager *) fileManager
{
    return [[mFileManager retain] autorelease]; 
}

- (void) setFileManager: (MameFileManager *) theFileManager
{
    if (mFileManager != theFileManager)
    {
        [mFileManager release];
        mFileManager = [theFileManager retain];
    }
}

- (void) dealloc
{
    if (mSaveGame != 0)
        free(mSaveGame);
    if (mBios != 0)
        free(mBios);
    
    [super dealloc];
}

- (void) loadUserDefaults;
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

    [self loadDefaultPaths: defaults];

    [self setThrottled: [defaults boolForKey: MameThrottledKey]];
    [self setSyncToRefresh: [defaults boolForKey: MameSyncToRefreshKey]];
    [self setSoundEnabled: [defaults boolForKey: MameSoundEnabled]];
    [self setRenderInCV: [defaults boolForKey: MameRenderInCV]];
    [self setClearToRed: [defaults boolForKey: MameClearToRed]];
    
#ifdef MAME_DEBUG
    options.mame_debug = [defaults boolForKey: MameDebugKey];
#endif
    options.cheat = [defaults boolForKey: MameCheatKey];
    options.skip_disclaimer = [defaults boolForKey: MameSkipDisclaimerKey];
    options.skip_gameinfo = [defaults boolForKey: MameSkipGameInfoKey];
    options.skip_warnings = [defaults boolForKey: MameSkipWarningsKey];
    
    options.samplerate = [defaults integerForKey: MameSampleRateKey];
    options.use_samples = [defaults boolForKey: MameUseSamplesKey];
    
    options.brightness = [defaults floatForKey: MameBrightnessKey];
    options.contrast = [defaults floatForKey: MameContrastKey];
    options.gamma = [defaults floatForKey: MameGammaKey];
    options.pause_bright = [defaults floatForKey: MamePauseBrightnessKey];
    
    options.beam = (int) ([defaults floatForKey: MameBeamWidthKey] * 65536.0f);
    options.antialias = [defaults boolForKey: MameAntialiasBeamKey];
    options.vector_flicker = [defaults floatForKey: MameVectorFlickerKey];
    
    [self setSaveGame: [[defaults stringForKey: MameSaveGameKey] UTF8String]];
    options.savegame = mSaveGame;
    options.auto_save = [defaults boolForKey: MameAutosaveKey];
    [self setBios: [[defaults stringForKey: MameBiosKey] UTF8String]];
    options.bios = mBios;
}

//=========================================================== 
//  throttled 
//=========================================================== 
- (BOOL) throttled
{
    return mThrottled;
}

- (void) setThrottled: (BOOL) flag
{
    mThrottled = flag;
}

//=========================================================== 
//  syncToRefresh 
//=========================================================== 
- (BOOL) syncToRefresh
{
    return mSyncToRefresh;
}

- (void) setSyncToRefresh: (BOOL) flag
{
    mSyncToRefresh = flag;
}

//=========================================================== 
//  soundEnabled 
//=========================================================== 
- (BOOL) soundEnabled
{
    return mSoundEnabled;
}

- (void) setSoundEnabled: (BOOL) flag
{
    mSoundEnabled = flag;
}

//=========================================================== 
//  renderInCV 
//=========================================================== 
- (BOOL) renderInCV
{
    return mRenderInCV;
}

- (void) setRenderInCV: (BOOL) flag
{
    mRenderInCV = flag;
}

//=========================================================== 
//  clearToRed 
//=========================================================== 
- (BOOL) clearToRed;
{
    return mClearToRed;
}

- (void) setClearToRed: (BOOL) clearToRed;
{
    mClearToRed = clearToRed;
}

//=========================================================== 
//  saveGame 
//=========================================================== 
- (char *) saveGame
{
    return mSaveGame; 
}

- (void) setSaveGame: (char *) newSaveGame
{
    if (mSaveGame != 0)
    {
        free(mSaveGame);
        mSaveGame = 0;
    }
    
    if (newSaveGame != 0)
    {
        mSaveGame = malloc(strlen(newSaveGame) + 1);
        strcpy(mSaveGame, newSaveGame);
    }
}

//=========================================================== 
//  bios 
//=========================================================== 
- (char *) bios
{
    return mBios; 
}

- (void) setBios: (char *) newBios
{
    if (mBios != 0)
    {
        free(mBios);
        mBios = 0;
    }
    
    if (newBios != 0)
    {
        mBios = malloc(strlen(newBios) + 1);
        strcpy(mBios, newBios);
    }
}

@end

@implementation MameConfiguration (Private)

+ (void) initializeDefaultPaths: (NSMutableDictionary *) defaultValues;
{
    const struct
    {
        NSString * preference;
        NSString * path;
    }
    defaultPaths[] = {
    { MameRomPath,          @"ROMs" },
    { MameSamplePath,       @"Sound Samples" },
    { MameConfigPath,       @"Config" },
    { MameNvramPath,        @"NVRAM" },
    { MameMemcardPath,      @"Memcard" },
    { MameInputPath,        @"Input" },
    { MameHighScorePath,    @"High Scores" },
    { MameStatePath,        @"States" },
    { MameArtworkPath,      @"Cabinet Art" },
    { MameSnapshotPath,     @"Screenshots" },
    { 0, nil }
    };
    
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * baseDirectory = @"";
    if ([paths count] > 0)
    {
        baseDirectory = [paths objectAtIndex: 0];
        baseDirectory = [baseDirectory stringByAppendingPathComponent: @"MacMAME User Data"];
    }
    
    int i;
    for (i = 0; defaultPaths[i].path != nil; i++)
    {
        NSString * path = [baseDirectory stringByAppendingPathComponent: defaultPaths[i].path];
        [defaultValues setObject: path forKey: defaultPaths[i].preference];
    }
}

- (void) loadDefaultPaths: (NSUserDefaults *) defaults;
{
    const struct
    {
        const char * pathtype;
        NSString * preference;
    }
    defaultPaths[] = {
    { OPTION_ROMPATH,         MameRomPath },
    // { FILETYPE_IMAGE,       MameRomPath },
    { OPTION_DIFF_DIRECTORY,  MameDiffPath },
    { OPTION_SAMPLEPATH,      MameSamplePath },
    { OPTION_ARTPATH,     MameArtworkPath },
    { OPTION_NVRAM_DIRECTORY,       MameNvramPath },
    // { FILETYPE_HIGHSCORE,   MameHighScorePath },
    { OPTION_CFG_DIRECTORY,      MameConfigPath },
    { OPTION_INPUT_DIRECTORY,    MameInputPath },
    { OPTION_STATE_DIRECTORY,       MameStatePath },
    { OPTION_MEMCARD_DIRECTORY,     MameMemcardPath },
    { OPTION_SNAPSHOT_DIRECTORY,  MameSnapshotPath },
    { OPTION_SNAPSHOT_DIRECTORY,       MameSnapshotPath },
    { OPTION_CTRLRPATH,       MameCtrlrPath },
    { OPTION_COMMENT_DIRECTORY,     MameCommentPath },
    { 0, nil }
    };
    
    int i;
    for (i = 0; defaultPaths[i].preference != nil; i++)
    {
        NSString * defaultValue = [defaults stringForKey: defaultPaths[i].preference];
        if (defaultValue == nil)
            continue;
        NSString * path = [mFileManager resolveAlias: defaultValue];
        options_set_string(defaultPaths[i].pathtype, [path UTF8String]);
    }
}

@end
