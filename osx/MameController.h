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
#import <QuartzCore/QuartzCore.h>
#import "JRLog.h"

#if defined(__cplusplus)
extern "C" {
#endif
    
#include "osdepend.h"
#include "render.h"

#if defined(__cplusplus)
}
#endif

@class PreferencesWindowController;
@class MameView;
@class MameConfiguration;
@class VersionChecker;
@class AudioEffectWindowController;

@interface MameController : NSObject <JRLogLogger>
{
    IBOutlet MameView * mMameView;
    IBOutlet NSDrawer * mDrawer;
    IBOutlet NSWindow * mOpenPanel;
    IBOutlet NSComboBox * mGameTextField;
    IBOutlet VersionChecker *mVersionChecker;
    IBOutlet NSMenu * mEffectsMenu;
    
    IBOutlet NSPanel * mMameLogPanel;
    IBOutlet NSTextView * mMameLogView;
    
    // Size of other elements around the view
    NSSize mExtraWindowSize;
    
    PreferencesWindowController * mPreferencesController;
    AudioEffectWindowController * mAudioEffectsController;

    MameConfiguration * mConfiguration;

    BOOL mMameIsRunning;
    
    NSMutableArray * mEffectNames;
    NSMutableDictionary * mEffectPathsByName;
    BOOL mVisualEffectEnabled;
    int mCurrentEffectIndex;

    NSString * mGameName;
    NSString * mLoadingMessage;
    NSMutableArray * mPreviousGames;
    BOOL mGameLoading;
    BOOL mGameRunning;
    BOOL mQuitOnError;
    
    NSDictionary * mLogAttributes;
    NSDictionary * mLogErrorAttributes;
    NSDictionary * mLogWarningAttributes;
    NSDictionary * mLogInfoAttributes;
    NSDictionary * mLogDebugAttributes;
    id<JRLogLogger> mOriginalLogger;
}

- (MameView *) mameView;

- (BOOL) visualEffectEnabled;
- (void) setVisualEffectEnabled: (BOOL) flag;

- (int) currentEffectIndex;
- (void) setCurrentEffectIndex: (int) currentEffectIndex;

- (void) setCurrentVisualEffectName: (NSString *) effectName;

- (NSArray *) visualEffectNames;

- (IBAction) nextVisualEffect: (id) sender;
- (IBAction) previousVisualEffects: (id) sender;
- (IBAction) visualEffectsMenuChanged: (id) sender;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) fullScreen;
- (void) setFullScreen: (BOOL) fullScreen;

- (BOOL) linearFilter;
- (void) setLinearFilter: (BOOL) linearFilter;

- (BOOL) audioEffectEnabled;
- (void) setAudioEffectEnabled: (BOOL) flag;

- (IBAction) showAudioEffectsPanel: (id) sender;

- (BOOL) isGameLoading;
- (BOOL) isGameRunning;

- (NSString *) loadingMessage;

- (NSArray *) previousGames;

- (IBAction) showPreferencesPanel: (id) sender;

- (IBAction) togglePause: (id) sender;
- (IBAction) nullAction: (id) sender;

- (IBAction) raiseOpenPanel: (id) sender;
- (IBAction) endOpenPanel: (id) sender;
- (IBAction) cancelOpenPanel: (id) sender;
- (IBAction) hideOpenPanel: (id) sender;

- (IBAction) resizeToActualSize: (id) sender;
- (IBAction) resizeToDoubleSize: (id) sender;
- (IBAction) resizeToOptimalSize: (id) sender;
- (IBAction) resizeToMaximumIntegralSize: (id) sender;
- (IBAction) resizeToMaximumSize: (id) sender;

- (IBAction) auditRoms: (id) sender;

- (IBAction) showLogWindow: (id) sender;

- (IBAction) clearLogWindow: (id) sender;

- (IBAction) showReleaseNotes: (id) sender;

- (IBAction) showWhatsNew: (id) sender;

- (void) logWithLevel: (JRLogLevel) callerLevel
             instance: (NSString*) instance
                 file: (const char*) file
                 line: (unsigned) line
             function: (const char*) function
              message: (NSString*) message;

#pragma mark -
#pragma mark MameView delegates

- (void) mameWillStartGame: (NSNotification *) notification;

- (void) mameDidFinishGame: (NSNotification *) notification;

- (void) mameErrorMessage: (NSString *) message;

- (void) mameWarningMessage: (NSString *) message;

- (void) mameInfoMessage: (NSString *) message;

- (void) mameDebugMessage: (NSString *) message;

- (void) mameLogMessage: (NSString *) message;

@end
