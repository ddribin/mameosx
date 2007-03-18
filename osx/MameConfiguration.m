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

- (void) setStringOption: (NSString *) stringValue
                withName: (const char *) name;

- (NSString *) getStringOption: (const char *) name;

- (void) setBoolOption: (BOOL) boolValue
              withName: (const char *) name;

- (void) setIntOption: (int) intValue
             withName: (const char *) name;

- (void) setFloatOption: (float) floatValue
               withName: (const char *) name;

@end

@implementation MameConfiguration
- (id) init
{
    self = [super init];
    if (self == nil)
        return nil;

    options_init(NULL);

    return self;
}

- (void) dealloc
{
    if (mSaveGame != 0)
        free(mSaveGame);
    if (mBios != 0)
        free(mBios);
    
    [super dealloc];
}

#pragma mark -
#pragma mark Directories and paths

- (void) setRomPath: (NSString *) romPath;
{
    [self setStringOption: romPath withName: OPTION_ROMPATH];
}

- (void) setSamplePath: (NSString *) samplePath;
{
    [self setStringOption: samplePath withName: OPTION_SAMPLEPATH];
}

- (void) setArtworkPath: (NSString *) artworkPath;
{
    [self setStringOption: artworkPath withName: OPTION_ARTPATH];
}

- (void) setDiffDirectory: (NSString *) diffDirectory;
{
    [self setStringOption: diffDirectory withName: OPTION_DIFF_DIRECTORY];
}

- (void) setNvramDirectory: (NSString *) nvramDirectory;
{
    [self setStringOption: nvramDirectory withName: OPTION_NVRAM_DIRECTORY];
}

- (void) setConfigDirectory: (NSString *) configDirectory;
{
    [self setStringOption: configDirectory withName: OPTION_CFG_DIRECTORY];
}

- (void) setInputDirectory: (NSString *) inputDirectory;
{
    [self setStringOption: inputDirectory withName: OPTION_INPUT_DIRECTORY];
}

- (void) setStateDirectory: (NSString *) stateDirectory;
{
    [self setStringOption: stateDirectory withName: OPTION_STATE_DIRECTORY];
}

- (void) setMemcardDirectory: (NSString *) memcardDirectory;
{
    [self setStringOption: memcardDirectory withName: OPTION_MEMCARD_DIRECTORY];
}

- (void) setSnapshotDirectory: (NSString *) snapshotDirectory;
{
    [self setStringOption: snapshotDirectory withName: OPTION_SNAPSHOT_DIRECTORY];
}

- (void) setCtrlrPath: (NSString *) ctlrPath;
{
    [self setStringOption: ctlrPath withName: OPTION_CTRLRPATH];
}

- (void) setCommentDirectory: (NSString *) commentDirectory;
{
    [self setStringOption: commentDirectory withName: OPTION_COMMENT_DIRECTORY];
}

- (void) setFontPath: (NSString *) fontPath;
{
    [self setStringOption: fontPath withName: OPTION_FONTPATH];
}

- (NSString *) fontPath;
{
    return [self getStringOption: OPTION_FONTPATH];
}

#pragma mark -

#ifdef MAME_DEBUG
- (void) setMameDebug: (BOOL) mameDebug;
{
    options.mame_debug = mameDebug;
}
#endif

- (void) setCheat: (BOOL) cheat;
{
    options.cheat = cheat;
}

#pragma mark -
#pragma mark Messages

- (void) setSkipDisclaimer: (BOOL) skipDisclaimer;
{
    options.skip_disclaimer = skipDisclaimer;
}

- (void) setSkipGameInfo: (BOOL) skipGameInfo;
{
    options.skip_gameinfo = skipGameInfo;
}

- (void) setSkipWarnings: (BOOL) skipWarnings;
{
    options.skip_warnings = skipWarnings;
}

#pragma mark -
#pragma mark Sound

- (void) setSampleRate: (int) sampleRate;
{
    options.samplerate = sampleRate;
}

- (void) setUseSamples: (BOOL) useSamples;
{
    options.use_samples = useSamples;
}

#pragma mark -
#pragma mark Graphics

- (void) setBrightness: (float) brightness;
{
    options.brightness = brightness;
}

- (void) setContrast: (float) contrast;
{
    options.contrast = contrast;
}

- (void) setGamma: (float) gamma;
{
    options.gamma = gamma;
}

- (void) setPauseBrightness: (float) pauseBrightness;
{
    options.pause_bright = pauseBrightness;
}

#pragma mark -
#pragma mark Vector

- (void) setBeam: (int) beam;
{
    options.beam = beam;
}

- (void) setAntialias: (BOOL) antialias;
{
    options.antialias = antialias;
}

- (void) setVectorFlicker: (BOOL) vectorFlicker;
{
    options.vector_flicker = vectorFlicker;
}

#pragma mark -

//=========================================================== 
//  saveGame 
//=========================================================== 
- (NSString *) saveGame
{
    return [NSString stringWithUTF8String: mSaveGame]; 
}

- (void) setSaveGame: (NSString *) newSaveGame
{
    if (mSaveGame != 0)
    {
        free(mSaveGame);
        mSaveGame = 0;
    }
    
    if (newSaveGame != 0)
    {
        const char * utf8SaveGame = [newSaveGame UTF8String];
        mSaveGame = malloc(strlen(utf8SaveGame) + 1);
        strcpy(mSaveGame, utf8SaveGame);
    }
    options.savegame = mSaveGame;
}

- (void) setAutoSave: (BOOL) autoSave;
{
    options.auto_save = autoSave;
}

//=========================================================== 
//  bios 
//=========================================================== 
- (NSString *) bios
{
    return [NSString stringWithUTF8String: mBios]; 
}

- (void) setBios: (NSString *) newBios
{
    if (mBios != 0)
    {
        free(mBios);
        mBios = 0;
    }
    
    if (newBios != 0)
    {
        const char * utf8Bios = [newBios UTF8String];
        mBios = malloc(strlen(utf8Bios) + 1);
        strcpy(mBios, utf8Bios);
    }
    options.bios = mBios;
}

@end

@implementation MameConfiguration (Private)


- (void) setStringOption: (NSString *) stringValue
                withName: (const char *) name;
{
    if (stringValue == nil)
        return;
    options_set_string(name, [stringValue UTF8String]);
}

- (NSString *) getStringOption: (const char *) name;
{
    const char * value = options_get_string(name);
    return [NSString stringWithUTF8String: value];
}

- (void) setBoolOption: (BOOL) boolValue
              withName: (const char *) name;
{
    options_set_bool(name, boolValue);
}

- (void) setIntOption: (int) intValue
             withName: (const char *) name;
{
    options_set_int(name, intValue);
}

- (void) setFloatOption: (float) floatvalue
               withName: (const char *) name;
{
    options_set_float(name, floatvalue);
}

@end
