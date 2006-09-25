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
            width: (float) windowWidth
           height: (float) windowHeight;
{
    mWindowWidth = windowWidth;
    mWindowHeight = windowHeight;
    mTextureTable = [[MameTextureTable alloc] init];
    
    //Create the OpenGL context used to render the composition (a separate OpenGL context from the destination one is needed to render into CoreVideo OpenGL buffers)
    NSOpenGLPixelFormat * glPixelFormat = mameViewFormat;
    mGlContext = [[NSOpenGLContext alloc] initWithFormat:glPixelFormat shareContext:nil];
    [mGlContext makeCurrentContext];
    
    glShadeModel(GL_SMOOTH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    
    glViewport(0.0, 0.0, (GLsizei)mWindowWidth, (GLsizei)mWindowHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, (GLdouble)mWindowWidth, (GLdouble)mWindowHeight, 0.0, 0.0, -1.0);
    
    
    NSMutableDictionary * bufferOptions = [NSMutableDictionary dictionary];
    [bufferOptions setValue:[NSNumber numberWithInt: mWindowWidth]
                     forKey:(NSString*)kCVOpenGLBufferWidth];
    [bufferOptions setValue:[NSNumber numberWithInt: mWindowHeight]
                     forKey:(NSString*)kCVOpenGLBufferHeight];
    if (CVOpenGLBufferCreate(NULL, mWindowWidth, mWindowHeight, (CFDictionaryRef)bufferOptions,
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
    [mOpenGLRenderer osd_init: mGlContext format: glPixelFormat
                        width: windowWidth height: windowHeight];
}

- (void) renderFrame: (const render_primitive_list *) primlist
{
    CVOpenGLTextureRelease(mCurrentFrameTexture);
    mCurrentFrameTexture = NULL;
    CVOpenGLTextureCacheFlush(mFrameTextureCache, 0);
    
    // Use the buffer as the OpenGL context destination
    if(CVOpenGLBufferAttach(mCurrentFrame, (CGLContextObj) [mGlContext CGLContextObj], 0, 0, 0) == kCVReturnSuccess)
    {
        [mOpenGLRenderer renderFrame: primlist];
        glFlush();
        CVOpenGLTextureCacheCreateTextureFromImage(NULL, mFrameTextureCache,
                                                   mCurrentFrame,
                                                   0, &mCurrentFrameTexture);
    }
}

@end
