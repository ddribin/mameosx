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

#import "MamePreferences.h"
#import "MameConfiguration.h"

@interface MamePreferences (Private)

- (BOOL) hasMultipleCPUs;
- (void) initializeDefaultPaths: (NSMutableDictionary *) defaultValues;

@end


static MamePreferences * sInstance;

NSString * MameVersionUrlKey = @"VersionUrl";
NSString * MameCheckUpdatesAtStartupKey = @"CheckUpdatesAtStartup";
NSString * MameGameKey = @"Game";
NSString * MameSleepAtExitKey = @"SleepAtExit";
NSString * MamePreviousGamesKey = @"PreviousGames";

NSString * MameThrottledKey = @"Throttled";
NSString * MameSyncToRefreshKey = @"SyncToRefresh";
NSString * MameSoundEnabledKey = @"SoundEnabled";
NSString * MameRenderInCVKey = @"RenderInCV";
NSString * MameClearToRedKey = @"ClearToRed";
NSString * MameLinearFilterKey = @"LinearFilter";

NSString * MameRomPath = @"RomPath";
NSString * MameSamplePath = @"SamplePath";
NSString * MameConfigPath = @"ConfigPath";
NSString * MameNvramPath = @"NvramPath";
NSString * MameMemcardPath = @"MemcardPath";
NSString * MameInputPath = @"InputPath";
NSString * MameStatePath = @"StatePath";
NSString * MameArtworkPath = @"ArtworkPath";
NSString * MameSnapshotPath = @"SnapshotPath";
NSString * MameDiffPath = @"DiffPath";
NSString * MameCtrlrPath = @"CtrlrPath";
NSString * MameCommentPath = @"CommentPath";
NSString * MameCheatPath = @"CheatPath";

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
#pragma mark User defaults

- (void) registerDefaults;
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
                      forKey: MameSoundEnabledKey];
    
    if ([self hasMultipleCPUs])
    {
        [defaultValues setObject: [NSNumber numberWithBool: YES]
                          forKey: MameRenderInCVKey];
    }
    else
    {
        [defaultValues setObject: [NSNumber numberWithBool: NO]
                          forKey: MameRenderInCVKey];
    }
    
    [defaultValues setObject: [NSNumber numberWithBool: NO]
                      forKey: MameClearToRedKey];

    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameLinearFilterKey];
    
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
    
    [mDefaults registerDefaults: defaultValues];
}

- (void) synchronize;
{
    [mDefaults synchronize];
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

- (BOOL) linearFilter;
{
    return [mDefaults boolForKey: MameLinearFilterKey];
}

- (void) setLinearFilter: (BOOL) linearFilter;
{
    [mDefaults setBool: linearFilter forKey: MameLinearFilterKey];
}

- (BOOL) checkUpdatesAtStartup;
{
    return [mDefaults boolForKey: MameCheckUpdatesAtStartupKey];
}

- (NSArray *) previousGames;
{
    return [mDefaults arrayForKey: MamePreviousGamesKey];
}

- (void) setPreviousGames: (NSArray *) previousGames;
{
    [mDefaults setObject: previousGames forKey: MamePreviousGamesKey];
}

#pragma mark -
#pragma mark Private MAME OS X Options

- (NSString *) versionUrl;
{
    return [mDefaults stringForKey: MameVersionUrlKey];
}

- (NSString *) game;
{
    return [mDefaults stringForKey: MameGameKey];
}

- (BOOL) sleepAtExit;
{
    return [mDefaults boolForKey: MameSleepAtExitKey];
}

#pragma mark -
#pragma mark Directories and paths

- (NSString *) romPath;
{
    return [mDefaults stringForKey: MameRomPath];
}

- (NSString *) samplePath;
{
    return [mDefaults stringForKey: MameSamplePath];
}

- (NSString *) artworkPath;
{
    return [mDefaults stringForKey: MameArtworkPath];
}

- (NSString *) diffDirectory;
{
    return [mDefaults stringForKey: MameDiffPath];
}

- (NSString *) nvramDirectory;
{
    return [mDefaults stringForKey: MameNvramPath];
}

- (NSString *) configDirectory;
{
    return [mDefaults stringForKey: MameConfigPath];
}

- (NSString *) inputDirectory;
{
    return [mDefaults stringForKey: MameInputPath];
}

- (NSString *) stateDirectory;
{
    return [mDefaults stringForKey: MameStatePath];
}

- (NSString *) memcardDirectory;
{
    return [mDefaults stringForKey: MameMemcardPath];
}

- (NSString *) snapshotDirectory;
{
    return [mDefaults stringForKey: MameSnapshotPath];
}

- (NSString *) ctrlrPath;
{
    return [mDefaults stringForKey: MameCtrlrPath];
}

- (NSString *) commentDirectory;
{
    return [mDefaults stringForKey: MameCommentPath];
}

#pragma mark -

- (BOOL) mameDebug;
{
    return [mDefaults boolForKey: MameDebugKey];
}

- (BOOL) cheat;
{
    return [mDefaults boolForKey: MameCheatKey];
}

#pragma mark -
#pragma mark Messages

- (BOOL) skipDisclaimer;
{
    return [mDefaults boolForKey: MameSkipDisclaimerKey];
}

- (BOOL) skipGameInfo;
{
    return [mDefaults boolForKey: MameSkipGameInfoKey];
}

- (BOOL) skipWarnings;
{
    return [mDefaults boolForKey: MameSkipWarningsKey];
}

#pragma mark -
#pragma mark Sound

- (int) sampleRate;
{
    return [mDefaults integerForKey: MameSampleRateKey];
}

- (BOOL) useSamples;
{
    return [mDefaults boolForKey: MameUseSamplesKey];
}

#pragma mark -
#pragma mark Graphics

- (float) brightness;
{
    return [mDefaults floatForKey: MameBrightnessKey];
}

- (float) contrast;
{
    return [mDefaults floatForKey: MameContrastKey];
}

- (float) gamma;
{
    return [mDefaults floatForKey: MameGammaKey];
}

- (float) pauseBrightness;
{
    return [mDefaults floatForKey: MamePauseBrightnessKey];
}

#pragma mark -
#pragma mark Vector

- (float) beamWidth;
{
    return [mDefaults floatForKey: MameBeamWidthKey];
}

- (BOOL) antialiasBeam;
{
    return [mDefaults boolForKey: MameAntialiasBeamKey];
}

- (BOOL) vectorFlicker;
{
    return [mDefaults boolForKey: MameVectorFlickerKey];
}

#pragma mark -

- (NSString *) saveGame;
{
    return [mDefaults stringForKey: MameSaveGameKey];
}

- (BOOL) autoSave;
{
    return [mDefaults boolForKey: MameAutosaveKey];
}

- (NSString *) bios;
{
    return [mDefaults stringForKey: MameBiosKey];
}

#pragma mark -
#pragma mark Integration with MAME options

- (void) copyToMameConfiguration: (MameConfiguration *) configuration;
{
    [configuration setRomPath: [self romPath]];
    [configuration setSamplePath: [self samplePath]];
    [configuration setArtworkPath: [self artworkPath]];
    [configuration setDiffDirectory: [self diffDirectory]];
    [configuration setNvramDirectory: [self nvramDirectory]];
    [configuration setConfigDirectory: [self configDirectory]];
    [configuration setInputDirectory: [self inputDirectory]];
    [configuration setStateDirectory: [self stateDirectory]];
    [configuration setMemcardDirectory: [self memcardDirectory]];
    [configuration setSnapshotDirectory: [self snapshotDirectory]];
    [configuration setCtrlrPath: [self ctrlrPath]];
    [configuration setCommentDirectory: [self commentDirectory]];
    
#ifdef MAME_DEBUG
    [configuration setMameDebug: [self mameDebug]];
#endif
    [configuration setCheat: [self cheat]];
    [configuration setSkipDisclaimer: [self skipDisclaimer]];
    [configuration setSkipGameInfo: [self skipGameInfo]];
    [configuration setSkipWarnings: [self skipWarnings]];

    [configuration setSampleRate: [self sampleRate]];
    [configuration setUseSamples: [self useSamples]];
    
    [configuration setBrightness: [self brightness]];
    [configuration setContrast: [self contrast]];
    [configuration setGamma: [self gamma]];
    [configuration setPauseBrightness: [self pauseBrightness]];
    
    [configuration setBeam: (int) ([self beamWidth] * 65536.0f)];
    [configuration setAntialias: [self antialiasBeam]];
    [configuration setVectorFlicker: [self vectorFlicker]];
    
    [configuration setSaveGame: [self saveGame]];
    [configuration setAutoSave: [self autoSave]];
    [configuration setBios: [self bios]];
}

@end

@implementation MamePreferences (Private)

- (BOOL) hasMultipleCPUs;
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

- (void) initializeDefaultPaths: (NSMutableDictionary *) defaultValues;
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
    { MameStatePath,        @"States" },
    { MameArtworkPath,      @"Cabinet Art" },
    { MameSnapshotPath,     @"Screenshots" },
    { 0, nil }
    };

    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSAssert([paths count] > 0, @"Could not locate NSLibraryDirectory in user domain");

    NSString * baseDirectory = [paths objectAtIndex: 0];
    baseDirectory = [baseDirectory stringByAppendingPathComponent: @"Application Support"];
    if (![fileManager fileExistsAtPath: baseDirectory])
        [fileManager createDirectoryAtPath: baseDirectory attributes: nil];
    baseDirectory = [baseDirectory stringByAppendingPathComponent: @"MAME OS X"];
    if (![fileManager fileExistsAtPath: baseDirectory])
        [fileManager createDirectoryAtPath: baseDirectory attributes: nil];

    int i;
    for (i = 0; defaultPaths[i].path != nil; i++)
    {
        NSString * path = [baseDirectory stringByAppendingPathComponent: defaultPaths[i].path];
        if (![fileManager fileExistsAtPath: path])
            [fileManager createDirectoryAtPath: path attributes: nil];
        [defaultValues setObject: path forKey: defaultPaths[i].preference];
    }
}

@end

