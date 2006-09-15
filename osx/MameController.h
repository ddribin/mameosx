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

/* texture_info holds information about a texture */
typedef struct _texture_info texture_info;
struct _texture_info
{
	texture_info *			next;				// next texture in the list
	UINT32				hash;				// hash value for the texture
	UINT32				flags;				// rendering flags
	render_texinfo			texinfo;			// copy of the texture info
	float				ustart, ustop;			// beginning/ending U coordinates
	float				vstart, vstop;			// beginning/ending V coordinates
	int				rawwidth, rawheight;		// raw width/height of the texture
	int				type;				// what type of texture are we?
	int				borderpix;			// do we have a 1 pixel border?
	int				xprescale;			// what is our X prescale factor?
	int				yprescale;			// what is our Y prescale factor?
	int				uploadedonce;			// were we uploaded once already?
    
	UINT32				texturename;			// OpenGL texture "name"/ID
    
    CVPixelBufferRef    data;
    CVOpenGLTextureRef  cv_texture;
    
    
	UINT32				uploadlevel;			// you'll see...
};


@class MameView;
@class MameInputController;
@class MameAudioController;
@class MameConfiguration;

@interface MameController : NSObject
{
    IBOutlet MameView * mMameView;
    IBOutlet NSPopUpButton * mFilterButton;
    IBOutlet NSDrawer * mDrawer;
    MameInputController * mInputController;
    MameAudioController * mAudioController;
    MameConfiguration * mConfiguration;
    cycles_t mCyclesPerSecond;
    render_target * mTarget;
    int32_t mWindowWidth;
    int32_t mWindowHeight;
    texture_info * mTextList;

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
    cycles_t mThrottleLastCycles;
    mame_time mThrottleRealtime;
    mame_time mThrottleEmutime;
}

- (MameConfiguration *) configuration;

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

- (cycles_t) osd_cycles;
- (cycles_t) osd_cycles_per_second;
- (cycles_t) osd_profiling_ticks;

@end
