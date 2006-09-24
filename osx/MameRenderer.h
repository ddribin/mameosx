//
//  MameRenderer.h
//  mameosx
//
//  Created by Dave Dribin on 9/23/06.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include "render.h"

@class MameTextureTable;

@interface MameRenderer : NSObject
{
    MameTextureTable * mTextureTable;
    int32_t mWindowWidth;
    int32_t mWindowHeight;
    NSSize mCenteringOffset;

    NSOpenGLContext * mGlContext;
    CVOpenGLBufferPoolRef mBufferPool;
    CVOpenGLBufferRef mCurrentFrame;
    CVDisplayLinkRef mDisplayLink;
    CVOpenGLTextureCacheRef mFrameTextureCache;
    CVOpenGLTextureRef mCurrentFrameTexture;
    CVOpenGLTextureCacheRef mPrimTextureCache;
}

- (CVOpenGLTextureRef) currentFrameTexture;

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat
            width: (float) windowWidth
           height: (float) windowHeight;

- (void) updateVideo: (const render_primitive_list *) primlist;

@end
