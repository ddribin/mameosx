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
@class MameFilter;
@class VersionChecker;

@interface MameController : NSObject
{
    IBOutlet MameView * mMameView;
    IBOutlet NSPopUpButton * mFilterButton;
    IBOutlet NSDrawer * mDrawer;
    IBOutlet NSWindow * mOpenPanel;
    IBOutlet NSComboBox * mGameTextField;
    IBOutlet VersionChecker *mVersionChecker;
    
    IBOutlet NSPanel * mMameLogPanel;
    IBOutlet NSTextView * mMameLogView;
    
    PreferencesWindowController * mPreferencesController;

    MameConfiguration * mConfiguration;

    BOOL mMameIsRunning;
    
    BOOL mIsFiltered;
    NSMutableArray * mFilters;
    MameFilter * mCurrentFilter;

    NSString * mGameName;
    NSMutableArray * mPreviousGames;
    BOOL mGameLoading;
    BOOL mGameRunning;
    BOOL mQuitOnError;
    
    NSDictionary * mLogAttributes;
    NSDictionary * mLogErrorAttributes;
    NSDictionary * mLogWarningAttributes;
    NSDictionary * mLogInfoAttributes;
    NSDictionary * mLogDebugAttributes;
}

- (BOOL) isFiltered;
- (void) setIsFiltered: (BOOL) flag;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) fullScreen;
- (void) setFullScreen: (BOOL) fullScreen;

- (BOOL) isGameLoading;
- (BOOL) isGameRunning;

- (NSArray *) previousGames;

- (IBAction) showPreferencesPanel: (id) sender;

- (IBAction) filterChanged: (id) sender;
- (IBAction) togglePause: (id) sender;
- (IBAction) nullAction: (id) sender;

- (IBAction) raiseOpenPanel: (id) sender;
- (IBAction) endOpenPanel: (id) sender;
- (IBAction) cancelOpenPanel: (id) sender;
- (IBAction) hideOpenPanel: (id) sender;

- (IBAction) resizeToActualSize: (id) sender;
- (IBAction) resizeToDoubleSize: (id) sender;
- (IBAction) resizeToOptimalSize: (id) sender;

- (IBAction) showMameLog: (id) sender;

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
