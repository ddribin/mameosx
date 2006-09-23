//
//  MameController.h
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

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

@class MameView;
@class MameInputController;
@class MameAudioController;
@class MameTimingController;
@class MameFileManager;
@class MameConfiguration;
@class MameTextureTable;

@interface MameController : NSObject
{
    IBOutlet MameView * mMameView;
    IBOutlet NSPopUpButton * mFilterButton;
    IBOutlet NSDrawer * mDrawer;
    MameInputController * mInputController;
    MameAudioController * mAudioController;
    MameTimingController * mTimingController;
    MameFileManager * mFileManager;
    MameConfiguration * mConfiguration;

    MameTextureTable * mTextureTable;
    render_target * mTarget;
    int32_t mWindowWidth;
    int32_t mWindowHeight;
    NSSize mCenteringOffset;

    NSRecursiveLock * mLock;
    NSOpenGLContext * mGlContext;
    CVOpenGLBufferPoolRef mBufferPool;
    CVOpenGLBufferRef mCurrentFrame;
    CVDisplayLinkRef mDisplayLink;
    CVOpenGLTextureCacheRef mFrameTextureCache;
    CVOpenGLTextureRef mCurrentFrameTexture;
    CVOpenGLTextureCacheRef mPrimTextureCache;

    uint64_t mFramesDisplayed;
    uint64_t mFramesRendered;
    cycles_t mFrameStartTime;
    cycles_t mFrameEndTime;
    
    BOOL mIsFiltered;
    NSMutableArray * mFilters;
    CIFilter * mCurrentFilter;
    float inputCenterX;
    float inputCenterY;
    BOOL mMoveInputCenter;
    
    BOOL mSyncToRefresh;
    BOOL mThrottled;
}

- (MameConfiguration *) configuration;

- (MameFileManager *) fileManager;

- (BOOL) isFiltered;
- (void) setIsFiltered: (BOOL) flag;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (IBAction) filterChanged: (id) sender;
- (IBAction) togglePause: (id) sender;
- (IBAction) nullAction: (id) sender;

- (int) osd_init;
- (int) osd_update: (mame_time) emutime;

@end
