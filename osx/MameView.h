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
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import "DDCustomOpenGLView.h"

#include "osdepend.h"
#include "render.h"

@class MameController;
@class MameRenderer;
@class MameInputController;
@class MameAudioController;
@class MameTimingController;
@class MameFileManager;
@class MameConfiguration;
@class MameFilter;

@interface MameView : DDCustomOpenGLView
{
    IBOutlet MameController * mController;
    CIContext * mCiContext;
    CIContext * mFullScreenCiContext;
    
    id mDelegate;
    
    NSString * mGame;
    int mGameIndex;

    running_machine * mMachine;
    render_target * mTarget;
    const render_primitive_list * mPrimitives;
    MameRenderer * mRenderer;
    BOOL mCoreImageAccelerated;
    NSSize mRenderSize;
    
    BOOL mRenderInCoreVideoThread;
    MameFilter * mFilter;
    NSSize mNaturalSize;
    NSSize mOptimalSize;
    NSSize mFullScreenSize;
    BOOL mClearToRed;
    
    MameInputController * mInputController;
    MameAudioController * mAudioController;
    MameTimingController * mTimingController;
    MameFileManager * mFileManager;

    BOOL mMameIsRunning;
    NSLock * mMameLock;
    NSAutoreleasePool * mMamePool;

    uint64_t mFramesDisplayed;
    uint64_t mFramesRendered;
    cycles_t mFrameStartTime;
    cycles_t mFrameEndTime;

    BOOL mThrottled;
    
    BOOL mUnpauseOnFullScreenTransition;
}

- (NSString *) game;
- (BOOL) setGame: (NSString *) theGame;

- (BOOL) start;
- (void) stop;
- (void) togglePause;
- (BOOL) isRunning;

- (NSSize) naturalSize;
- (NSSize) optimalSize;

- (BOOL) renderInCoreVideoThread;
- (void) setRenderInCoreVideoThread: (BOOL) flag;

- (BOOL) clearToRed;
- (void) setClearToRed: (BOOL) clearToRed;

- (void) createCIContext;
- (CIContext *) ciContext;

- (MameFileManager *) fileManager;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) audioEnabled;
- (void) setAudioEnabled: (BOOL) flag;

- (MameFilter *) filter;
- (void) setFilter: (MameFilter *) aFilter;

- (int) osd_init: (running_machine *) machine;
- (void) mameDidExit: (running_machine *) machine;

#pragma mark -
#pragma mark OS Dependent API

- (int) osd_update: (mame_time) emutime;

- (void) osd_output_error: (const char *) utf8Format
                arguments: (va_list) argptr;

- (void) osd_output_warning: (const char *) utf8Format
                  arguments: (va_list) argptr;

- (void) osd_output_info: (const char *) utf8Format
               arguments: (va_list) argptr;

- (void) osd_output_debug: (const char *) utf8Format
                arguments: (va_list) argptr;

- (void) osd_output_log: (const char *) utf8Format
              arguments: (va_list) argptr;

- (id) delegagte;
- (void) setDelegate: (id) delegate;

@end

@interface NSObject (MameViewDelegateMethods)

- (void) mameWillStartGame: (NSNotification *) notification;

- (void) mameDidFinishGame: (NSNotification *) notification;

- (void) mameErrorMessage: (NSString *) message;

- (void) mameWarningMessage: (NSString *) message;

- (void) mameInfoMessage: (NSString *) message;

- (void) mameDebugMessage: (NSString *) message;

- (void) mameLogMessage: (NSString *) message;

@end

extern NSString * MameWillStartGame;
extern NSString * MameDidFinishGame;
extern NSString * MameExitStatusKey;

// These should corresponed to MAMERR_* in mame.h

enum
{
    MameExitStatusSuccess = 0,
    MameExitStatusFailedValidity = 1,
    MameExitStatusMissingFiles = 2,
    MameExitStatusFatalError = 3
};

