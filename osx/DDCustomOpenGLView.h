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

@interface DDCustomOpenGLView : NSView
{
    NSRecursiveLock * mOpenGLLock;
    NSOpenGLContext * mOpenGLContext;
    NSOpenGLPixelFormat * mPixelFormat;
    
    NSOpenGLContext * mFullScreenOpenGLContext;
    NSOpenGLPixelFormat * mFullScreenPixelFormat;

    BOOL mFullScreen;
    int mFullScreenWidth;
    int mFullScreenHeight;
    int mFullScreenRefreshRate;
    NSRect mFullScreenRect;
    float mFullScreenMouseOffset;
    float mFadeTime;

    CVDisplayLinkRef mDisplayLink;
    NSTimer * mAnimationTimer;
    
    BOOL mDoubleBuffered;
}

+ (NSOpenGLPixelFormat*)defaultPixelFormat;

- (id) initWithFrame: (NSRect) frame
         pixelFormat: (NSOpenGLPixelFormat *) pixelFormat;

- (NSOpenGLContext *) openGLContext;
- (void) setOpenGLContext: (NSOpenGLContext *) anOpenGLContext;

- (NSOpenGLPixelFormat *) pixelFormat;
- (void) setPixelFormat: (NSOpenGLPixelFormat *) aPixelFormat;

- (void) prepareOpenGL: (NSOpenGLContext *) context;

- (void) update;

- (void) lockOpenGLLock;
- (void) unlockOpenGLLock;

#pragma mark -
#pragma mark Active OpenGL Properties

- (NSOpenGLContext *) activeOpenGLContext;
- (NSOpenGLPixelFormat *) activePixelFormat;
- (NSRect) activeBounds;

#pragma mark -
#pragma mark Animation

- (void) startAnimation;
- (void) stopAnimation;
- (BOOL) isAnimationRunning;

- (void) updateAnimation;
- (void) drawFrame;

#pragma mark -
#pragma mark Full Screen

- (NSOpenGLContext *) fullScreenOpenGLContext;
- (void) setFullScreenOpenGLContext: (NSOpenGLContext *) aFullScreenOpenGLContext;

- (NSOpenGLPixelFormat *) fullScreenPixelFormat;
- (void) setFullScreenPixelFormat: (NSOpenGLPixelFormat *) aFullScreenPixelFormat;

- (void) setFullScreenWidth: (int) width height: (int) height;
- (int) fullScreenWidth;
- (int) fullScreenHeight;

- (void) setFullScreenRefreshRate: (int) fullScreenRefreshRate;
- (int) fullScreenRefreshRate;

- (void) setFadeTime: (float) fadeTime;
- (float) fadeTime;

- (BOOL) fullScreen;
- (void) setFullScreen: (BOOL) flag;

- (void) willEnterFullScreen;
- (void) willExitFullScreen;

- (void) didEnterFullScreen;
- (void) didExitFullScreen;

@end
