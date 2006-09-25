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

@class MameOpenGLRenderer;

@interface MameRenderer : NSObject
{
    MameOpenGLRenderer * mOpenGLRenderer;
    MameTextureTable * mTextureTable;
    int32_t mWindowWidth;
    int32_t mWindowHeight;
    NSSize mCenteringOffset;

    NSOpenGLContext * mGlContext;
    CVOpenGLBufferRef mCurrentFrame;
    CVOpenGLTextureCacheRef mFrameTextureCache;
    CVOpenGLTextureRef mCurrentFrameTexture;
}

- (CVOpenGLTextureRef) currentFrameTexture;

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat
            width: (float) windowWidth
           height: (float) windowHeight;

- (void) renderFrame: (const render_primitive_list *) primlist;

@end
