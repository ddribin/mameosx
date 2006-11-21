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
    char * mSaveGame;
    char * mBios;
}

#pragma mark -
#pragma mark Directories and paths

- (void) setRomPath: (NSString *) romPath;

- (void) setSamplePath: (NSString *) samplePath;

- (void) setArtworkPath: (NSString *) artworkPath;

- (void) setDiffDirectory: (NSString *) diffDirectory;

- (void) setNvramDirectory: (NSString *) nvramDirectory;

- (void) setConfigDirectory: (NSString *) configDirectory;

- (void) setInputDirectory: (NSString *) inputDirectory;

- (void) setStateDirectory: (NSString *) stateDirectory;

- (void) setMemcardDirectory: (NSString *) memcardDirectory;

- (void) setSnapshotDirectory: (NSString *) snapshotDirectory;

- (void) setCtrlrPath: (NSString *) ctlrPath;

- (void) setCommentDirectory: (NSString *) commentDirectory;

#pragma mark -

#ifdef MAME_DEBUG
- (void) setMameDebug: (BOOL) mameDebug;
#endif

- (void) setCheat: (BOOL) cheat;

#pragma mark -
#pragma mark Messages

- (void) setSkipDisclaimer: (BOOL) skipDisclaimer;

- (void) setSkipGameInfo: (BOOL) skipGameInfo;

- (void) setSkipWarnings: (BOOL) skipWarnings;

#pragma mark -
#pragma mark Sound

- (void) setSampleRate: (int) sampleRate;

- (void) setUseSamples: (BOOL) useSamples;

#pragma mark -
#pragma mark Graphics

- (void) setBrightness: (float) brightness;

- (void) setContrast: (float) contrast;

- (void) setGamma: (float) gamma;

- (void) setPauseBrightness: (float) pauseBrightness;

#pragma mark -
#pragma mark Vector

- (void) setBeam: (int) beam;

- (void) setAntialias: (BOOL) antialias;

- (void) setVectorFlicker: (BOOL) vectorFlicker;

#pragma mark -

- (NSString *) saveGame;
- (void) setSaveGame: (NSString *) newSaveGame;

- (void) setAutoSave: (BOOL) autoSave;

- (NSString *) bios;
- (void) setBios: (NSString *) newBios;

@end


