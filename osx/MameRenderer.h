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
    NSSize mCurrentFrameSize;
    NSSize mCenteringOffset;

    NSOpenGLContext * mGlContext;
    CVOpenGLBufferRef mCurrentFrame;
    CVOpenGLTextureCacheRef mFrameTextureCache;
    CVOpenGLTextureRef mCurrentFrameTexture;
}

- (CVOpenGLTextureRef) currentFrameTexture;

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat
             size: (NSSize) size;

- (void) renderFrame: (const render_primitive_list *) primitives
            withSize: (NSSize) size;

- (void) setOpenGLContext: (NSOpenGLContext *) context
              pixelFormat: (NSOpenGLPixelFormat *) pixelFormat;

@end
