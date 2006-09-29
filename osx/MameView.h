//
//  MameView.h
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

#include "osdepend.h"
#include "render.h"

@class MameController;
@class MameRenderer;
@class MameInputController;
@class MameAudioController;
@class MameTimingController;
@class MameFileManager;
@class MameConfiguration;

@interface MameView : NSOpenGLView
{
    IBOutlet MameController * mController;
    CIContext * mCiContext;
    
    NSString * mGame;
    int mGameIndex;

    render_target * mTarget;
    const render_primitive_list * mPrimitives;
    MameRenderer * mRenderer;
    BOOL mCoreImageAccelerated;
    GLenum mLastTextureTarget;

    NSRecursiveLock * mDisplayLock;
    CVDisplayLinkRef mDisplayLink;
    BOOL mRenderInCoreVideoThread;
    CIFilter * mCurrentFilter;
    int32_t mWindowWidth;
    int32_t mWindowHeight;
    
    float inputCenterX;
    float inputCenterY;
    BOOL mMoveInputCenter;
    
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

    BOOL mSyncToRefresh;
    BOOL mThrottled;
}

- (NSString *) game;
- (void) setGame: (NSString *) theGame;

- (BOOL) start;
- (void) stop;
- (void) togglePause;
- (BOOL) isRunning;

- (BOOL) renderInCoreVideoThread;
- (void) setRenderInCoreVideoThread: (BOOL) flag;

- (void) createCIContext;
- (CIContext *) ciContext;

- (MameFileManager *) fileManager;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) audioEnabled;
- (void) setAudioEnabled: (BOOL) flag;

- (int) osd_init;
- (int) osd_update: (mame_time) emutime;

@end
