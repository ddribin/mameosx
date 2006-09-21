//
//  MameConfiguration.m
//  mameosx
//
//  Created by Dave Dribin on 9/13/06.
//

#import "MameConfiguration.h"
#import "MameController.h"
#import "MameFileManager.h"
#include "mame.h"

@interface MameConfiguration (Private)

+ (void) initializeDefaultPaths: (NSMutableDictionary *) defaultValues;
- (void) loadDefaultPaths: (NSUserDefaults *) defaults;

@end

@implementation MameConfiguration

NSString * MameRomPath = @"RomPath";
NSString * MameConfigPath = @"ConfigPath";

NSString * MameThrottledKey = @"Throttled";
NSString * MameSyncToRefreshKey = @"SyncToRefresh";
NSString * MameSoundEnabled = @"SoundEnabled";

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


+ (void) initialize
{
    NSMutableDictionary * defaultValues = [NSMutableDictionary dictionary];
    
    [self initializeDefaultPaths: defaultValues];

    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameThrottledKey];
    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameSyncToRefreshKey];

    [defaultValues setObject: [NSNumber numberWithBool: YES]
                      forKey: MameSoundEnabled];
    
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

- (id) initWithController: (MameController *) controller;
{
    if ([super init] == nil)
        return nil;
    
    mController = controller;
    
    return self;
}

- (void) dealloc
{
    if (mRomPath != 0)
        free(mRomPath);
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
    
    options.debug_width = [defaults integerForKey: MameDebugWidthKey];
    options.debug_height = [defaults integerForKey: MameDebugHeightKey];
    options.debug_depth = [defaults integerForKey: MameDebugDepthKey];
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
//  romPath 
//=========================================================== 
- (char *) romPath
{
    return mRomPath; 
}

- (void) setRomPath: (char *) newRomPath
{
    if (mRomPath != 0)
    {
        free(mRomPath);
        mRomPath = 0;
    }

    if (newRomPath != 0)
    {
        mRomPath = malloc(strlen(newRomPath) + 1);
        strcpy(mRomPath, newRomPath);
    }
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
    { MameRomPath,          @"ROMs"},
    { MameConfigPath,       @"Config"},
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
        int pathtype;
        NSString * preference;
    }
    defaultPaths[] = {
    { FILETYPE_ROM,         MameRomPath },
    { FILETYPE_IMAGE,       MameRomPath },
    { FILETYPE_CONFIG,      MameConfigPath },
    { 0, nil }
    };
    
    MameFileManager * fileManager = [mController fileManager];
    int i;
    for (i = 0; defaultPaths[i].preference != nil; i++)
    {
        [fileManager setPath: [defaults stringForKey: defaultPaths[i].preference]
                     forType: defaultPaths[i].pathtype];
    }
}

@end
