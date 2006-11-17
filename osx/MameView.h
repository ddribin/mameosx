/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
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
- (int) osd_update: (mame_time) emutime;
- (int) osd_display_loading_rom_message: (const char *) name
                                romdata: (rom_load_data *) romdata;

- (id) delegagte;
- (void) setDelegate: (id) delegate;

@end

extern NSString * MameWillStartGame;
extern NSString * MameDidFinishGame;

@interface NSObject (MameViewDelegateMethods)

- (void) mameWillStartGame: (NSNotification *) notification;

- (void) mameDidFinishGame: (NSNotification *) notification;

- (void) mameRomLoadingMessage: (NSString *) name
                    romsLoaded: (int) romsLoaded
                      romCount: (int) romCount;

- (void) mameRomLoadingFinishedWithErrors: (BOOL) errors
                             errorMessage: (NSString *) errorMessage;

@end
