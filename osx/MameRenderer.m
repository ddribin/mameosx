//
//  MameRenderer.m
//  mameosx
//
//  Created by Dave Dribin on 9/23/06.
//

#import "MameRenderer.h"
#import "MameOpenGLRenderer.h"
#import "MameTextureTable.h"
#import "MameOpenGLTexture.h"

@interface MameRenderer (Private)

@end

static void cv_assert(CVReturn cr, NSString * message)
{
    if (cr != kCVReturnSuccess)
        NSLog(@"Core video returned: %d: %@", cr, message);
}

@implementation MameRenderer

- (CVOpenGLTextureRef) currentFrameTexture;
{
    return mCurrentFrameTexture;
}

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat
             size: (NSSize) size;
{
    mCurrentFrameSize = size;
    mTextureTable = [[MameTextureTable alloc] init];
    
    //Create the OpenGL context used to render the composition (a separate OpenGL context from the destination one is needed to render into CoreVideo OpenGL buffers)
    NSOpenGLPixelFormat * glPixelFormat = mameViewFormat;
    mGlContext = [[NSOpenGLContext alloc] initWithFormat:glPixelFormat shareContext:mameViewContext];
    [mGlContext makeCurrentContext];
    
    glShadeModel(GL_SMOOTH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    
    glViewport(0.0, 0.0, (GLsizei)mCurrentFrameSize.width, (GLsizei)mCurrentFrameSize.height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, (GLdouble)mCurrentFrameSize.width, (GLdouble)mCurrentFrameSize.height,
            0.0, 0.0, -1.0);
    
    
    NSMutableDictionary * bufferOptions = [NSMutableDictionary dictionary];
    [bufferOptions setValue:[NSNumber numberWithInt: mCurrentFrameSize.width]
                     forKey:(NSString*)kCVOpenGLBufferWidth];
    [bufferOptions setValue:[NSNumber numberWithInt: mCurrentFrameSize.height]
                     forKey:(NSString*)kCVOpenGLBufferHeight];
    if (CVOpenGLBufferCreate(NULL, mCurrentFrameSize.width,
                             mCurrentFrameSize.height,
                             (CFDictionaryRef)bufferOptions,
                             &mCurrentFrame))
    {
        NSLog(@"Could not create current frame buffer");
    }
    
    NSOpenGLContext * cacheContext = mameViewContext;
    NSOpenGLPixelFormat * cachePFormat = mameViewFormat;
    cv_assert(CVOpenGLTextureCacheCreate(NULL, 0, (CGLContextObj) [cacheContext CGLContextObj],
                                         (CGLPixelFormatObj) [cachePFormat CGLPixelFormatObj], 0, &mFrameTextureCache),
              @"Could not create frame texture cache");
    
    mOpenGLRenderer = [[MameOpenGLRenderer alloc] init];
    [mOpenGLRenderer osd_init: mGlContext format: glPixelFormat];
}

- (void) setOpenGLContext: (NSOpenGLContext *) context
              pixelFormat: (NSOpenGLPixelFormat *) pixelFormat;
{
}

- (void) renderFrame: (const render_primitive_list *) primitives
            withSize: (NSSize) size;
{
    [mGlContext makeCurrentContext];
    
    if (!NSEqualSizes(mCurrentFrameSize, size))
    {
        mCurrentFrameSize = size;
        
        CVOpenGLBufferRelease(mCurrentFrame);
        
        NSMutableDictionary * bufferOptions = [NSMutableDictionary dictionary];
        [bufferOptions setValue:[NSNumber numberWithInt: mCurrentFrameSize.width]
                         forKey:(NSString*)kCVOpenGLBufferWidth];
        [bufferOptions setValue:[NSNumber numberWithInt: mCurrentFrameSize.height]
                         forKey:(NSString*)kCVOpenGLBufferHeight];
        if (CVOpenGLBufferCreate(NULL, mCurrentFrameSize.width,
                                 mCurrentFrameSize.height,
                                 (CFDictionaryRef)bufferOptions,
                                 &mCurrentFrame))
        {
            NSLog(@"Could not create current frame buffer");
        }
    }
    
    glShadeModel(GL_SMOOTH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    
    glViewport(0.0, 0.0, (GLsizei)size.width, (GLsizei)size.height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, (GLdouble)size.width, (GLdouble)size.height, 0.0, 0.0, -1.0);
    
    CVOpenGLTextureRelease(mCurrentFrameTexture);
    mCurrentFrameTexture = NULL;
    CVOpenGLTextureCacheFlush(mFrameTextureCache, 0);
    
    // Use the buffer as the OpenGL context destination
    if(CVOpenGLBufferAttach(mCurrentFrame, (CGLContextObj) [mGlContext CGLContextObj], 0, 0, 0) == kCVReturnSuccess)
    {
        [mOpenGLRenderer renderFrame: primitives withSize: size];
        glFlush();
        CVOpenGLTextureCacheCreateTextureFromImage(NULL, mFrameTextureCache,
                                                   mCurrentFrame,
                                                   0, &mCurrentFrameTexture);
    }
    else
    {
        NSLog(@"CV error");
    }
}

@end
