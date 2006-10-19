//
//  DDCustomOpenGLView.m
//  DDCustomOpenGL
//
//  Created by Dave Dribin on 10/11/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DDCustomOpenGLView.h"

#define ANIMATE_WITH_DISPLAY_LINK 1

@interface DDCustomOpenGLView (Private)

- (void) initDisplayLink;
- (void) emptyThreadEntry;
- (void) surfaceNeedsUpdate: (NSNotification *) notification;
- (void) drawFrameInternal;
- (void) animationTimer;
- (BOOL) isDoubleBuffered: (NSOpenGLPixelFormat *) pixelFormat;
- (void) flushBuffer: (NSOpenGLContext *) context;

#pragma mark -
#pragma mark Full Screen

- (void) enterFullScreen;
- (void) exitFullScreen;
- (void) fullscreenEventLoop;
- (CGDisplayErr) setFullScreenParametersForDisplay: (CGDirectDisplayID) display
                                             width: (size_t) width 
                                            height: (size_t) height
                                           refresh: (CGRefreshRate) fps;
- (CGDisplayFadeReservationToken) displayFadeOut;
- (void) displayFadeIn: (CGDisplayFadeReservationToken) token;

@end

@implementation DDCustomOpenGLView

+ (NSOpenGLPixelFormat*)defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attribs[] = {0};
    return [[(NSOpenGLPixelFormat *)[NSOpenGLPixelFormat alloc] initWithAttributes:attribs] autorelease];
}

- (id) initWithFrame: (NSRect) frame
{
    return [self initWithFrame: frame
                   pixelFormat: [[self class] defaultPixelFormat]];
}

- (id) initWithFrame: (NSRect) frame
         pixelFormat: (NSOpenGLPixelFormat *) pixelFormat;
{
    self = [super initWithFrame: frame];
    if (self == nil)
        return nil;
    
    // Initialization code here.
    NSLog(@"initWithFrame: %@, %@", NSStringFromRect(frame), pixelFormat);
    
    mOpenGLContext = nil;
    mPixelFormat = [pixelFormat retain];
    
    mDoubleBuffered = [self isDoubleBuffered: mPixelFormat];

    mFullScreenOpenGLContext = nil;
    mFullScreenPixelFormat = nil;
    mFullScreen = NO;
    
    mOpenGLLock = [[NSRecursiveLock alloc] init];
    
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector(surfaceNeedsUpdate:)
               name: NSViewGlobalFrameDidChangeNotification
             object: self];


    mDisplayLink = NULL;
    mAnimationTimer = nil;
#if ANIMATE_WITH_DISPLAY_LINK
    NSLog(@"Animate with display link");
    [self initDisplayLink];
#else
    NSLog(@"Animate with timer");
#endif
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mOpenGLContext release];
    [mPixelFormat release];
    [mFullScreenOpenGLContext release];
    [mFullScreenPixelFormat release];
    [mOpenGLLock release];
    
    mOpenGLContext = nil;
    mPixelFormat = nil;
    mFullScreenOpenGLContext = nil;
    mFullScreenPixelFormat = nil;
    mOpenGLLock = nil;
    [super dealloc];
}

- (void) drawRect: (NSRect)rect
{
    [self lockOpenGLLock];
    NSOpenGLContext * currentContext = [self activeOpenGLContext];
    {
        [currentContext makeCurrentContext];
        [self drawFrame];
        // Don't flush the buffer here, as the window server does an implicit
        // swap, if necessary.
        // glFlush(); ???
        [self flushBuffer: currentContext];
    }
    [self unlockOpenGLLock];
}

//=========================================================== 
//  openGLContext 
//=========================================================== 
- (NSOpenGLContext *) openGLContext
{
    [self lockOpenGLLock];
    {
        if (mOpenGLContext == nil)
        {
            mOpenGLContext =
                [[NSOpenGLContext alloc] initWithFormat: mPixelFormat
                                           shareContext: nil];
            [mOpenGLContext makeCurrentContext];
            [self prepareOpenGL: mOpenGLContext];
        }
    }
    [self unlockOpenGLLock];
    return mOpenGLContext;
}

- (void) setOpenGLContext: (NSOpenGLContext *) anOpenGLContext
{
    [self lockOpenGLLock];
    {
        if (mOpenGLContext != anOpenGLContext)
        {
            [mOpenGLContext release];
            mOpenGLContext = [anOpenGLContext retain];
        }
    }
    [self unlockOpenGLLock];
}

//=========================================================== 
//  pixelFormat 
//=========================================================== 
- (NSOpenGLPixelFormat *) pixelFormat
{
    return mPixelFormat; 
}

- (void) setPixelFormat: (NSOpenGLPixelFormat *) aPixelFormat
{
    [self lockOpenGLLock];
    {
        if (mPixelFormat != aPixelFormat)
        {
            [mPixelFormat release];
            mPixelFormat = [aPixelFormat retain];
        }
    }
    [self unlockOpenGLLock];
}


- (void) prepareOpenGL: (NSOpenGLContext *) context;
{
    // for overriding to initialize OpenGL state, occurs after context creation
}

#pragma mark -
#pragma mark Active OpenGL Properties

- (NSOpenGLContext *) activeOpenGLContext;
{
    if (mFullScreen)
        return [self fullScreenOpenGLContext];
    else
        return [self openGLContext];
}

- (NSOpenGLPixelFormat *) activePixelFormat;
{
    if (mFullScreen)
        return [self fullScreenPixelFormat];
    else
        return [self pixelFormat];
}

- (NSRect) activeBounds;
{
    if (mFullScreen)
        return mFullScreenRect;
    else
        return [self bounds];
}

- (BOOL) isOpaque
{
    return YES;
}

- (void) lockFocus
{
    // make sure we are ready to draw
    [super lockFocus];
    
    [self lockOpenGLLock];
    {
        // get context. will create if we don't have one yet
        NSOpenGLContext* context = [self activeOpenGLContext];
        
        // when we are about to draw, make sure we are linked to the view
        if ([context view] != self)
        {
            [context setView: self];
        }
        
        // make us the current OpenGL context
        [context makeCurrentContext];
    }
    [self unlockOpenGLLock];
}

// no reshape will be called since NSView does not export a specific reshape method

- (void) update
{
    [self lockOpenGLLock];
    {
        NSOpenGLContext * context = [self activeOpenGLContext];
        
        if ([context view] == self)
        {
            [context update];
        }
    }
    [self unlockOpenGLLock];
}

- (void) lockOpenGLLock;
{
#if ANIMATE_WITH_DISPLAY_LINK
    [mOpenGLLock lock];
#endif
}

- (void) unlockOpenGLLock;
{
#if ANIMATE_WITH_DISPLAY_LINK
    [mOpenGLLock unlock];
#endif
}

#pragma mark -
#pragma mark Animation

- (void) startAnimation;
{
#if ANIMATE_WITH_DISPLAY_LINK
    CVDisplayLinkStart(mDisplayLink);
#else
    mAnimationTimer =
        [NSTimer scheduledTimerWithTimeInterval: 1.0f/60.0f
                                         target: self
                                       selector: @selector(animationTimer)
                                       userInfo: nil
                                        repeats: YES];
    [mAnimationTimer retain];
#endif    
}

- (void) stopAnimation;
{
#if ANIMATE_WITH_DISPLAY_LINK
    CVDisplayLinkStop(mDisplayLink);
#else
    [mAnimationTimer invalidate];
    [mAnimationTimer release];
    mAnimationTimer = nil;
#endif
}

- (BOOL) isAnimationRunning;
{
#if ANIMATE_WITH_DISPLAY_LINK
    return CVDisplayLinkIsRunning(mDisplayLink);
#else
    return (mAnimationTimer != nil);
#endif
}


- (void) updateAnimation;
{
}

- (void) drawFrame;
{
}

#pragma mark -
#pragma mark Full Screen

//=========================================================== 
//  fullScreenOpenGLContext 
//=========================================================== 
- (NSOpenGLContext *) fullScreenOpenGLContext
{
    [self lockOpenGLLock];
    {
        if ((mFullScreenOpenGLContext == nil) && (mFullScreenPixelFormat != nil))
        {
            mFullScreenOpenGLContext =
                [[NSOpenGLContext alloc] initWithFormat: mFullScreenPixelFormat
                                           shareContext: mOpenGLContext];
            [mFullScreenOpenGLContext makeCurrentContext];
            [self prepareOpenGL: mFullScreenOpenGLContext];
        }
    }
    [self unlockOpenGLLock];
    return mFullScreenOpenGLContext; 
}

- (void) setFullScreenOpenGLContext: (NSOpenGLContext *) aFullScreenOpenGLContext
{
    [self lockOpenGLLock];
    {
        if (mFullScreenOpenGLContext != aFullScreenOpenGLContext)
        {
            [mFullScreenOpenGLContext release];
            mFullScreenOpenGLContext = [aFullScreenOpenGLContext retain];
        }
    }
    [self unlockOpenGLLock];
}

//=========================================================== 
//  fullScreenPixelFormat 
//=========================================================== 
- (NSOpenGLPixelFormat *) fullScreenPixelFormat
{
    return mFullScreenPixelFormat; 
}

- (void) setFullScreenPixelFormat: (NSOpenGLPixelFormat *) aFullScreenPixelFormat
{
    [self lockOpenGLLock];
    {
        if (mFullScreenPixelFormat != aFullScreenPixelFormat)
        {
            [mFullScreenPixelFormat release];
            mFullScreenPixelFormat = [aFullScreenPixelFormat retain];
        }
    }
    [self unlockOpenGLLock];
}

- (void) setFullScreenWidth: (int) width height: (int) height;
{
    mFullScreenWidth = width;
    mFullScreenHeight = height;
}

- (int) fullScreenWidth;
{
    return mFullScreenWidth;
}

- (int) fullScreenHeight;
{
    return mFullScreenHeight;
}

//=========================================================== 
//  fullScreen 
//=========================================================== 
- (BOOL) fullScreen
{
    return mFullScreen;
}

- (void) setFullScreen: (BOOL) fullScreen
{
    if (fullScreen && !mFullScreen)
    {
        if ([self fullScreenOpenGLContext] != nil)
        {
            [self enterFullScreen];
            mFullScreen = YES;
        }
    }
    else if (!fullScreen && mFullScreen)
    {
        [self exitFullScreen];
        mFullScreen = NO;
    }
}

- (void) willEnterFullScreen;
{
}

- (void) willExitFullScreen;
{
}

- (void) didEnterFullScreen;
{
}

- (void) didExitFullScreen;
{
}

@end

#pragma mark -

@implementation DDCustomOpenGLView (Private)

CVReturn static myCVDisplayLinkOutputCallback(CVDisplayLinkRef displayLink, 
                                              const CVTimeStamp *inNow, 
                                              const CVTimeStamp *inOutputTime, 
                                              CVOptionFlags flagsIn, 
                                              CVOptionFlags *flagsOut, 
                                              void *displayLinkContext)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    DDCustomOpenGLView * view = (DDCustomOpenGLView *) displayLinkContext;
    [view updateAnimation];
    [view drawFrameInternal];
    [pool release];
    return kCVReturnSuccess;
}

- (void) initDisplayLink;
{
    // Detaching a thread forces [NSThread isMultiThreaded]
    // return YES. See:
    // http://developer.apple.com/documentation/Cocoa/Conceptual/Multithreading/articles/CocoaDetaching.html
    [NSThread detachNewThreadSelector: @selector(emptyThreadEntry)
                             toTarget: self
                           withObject: nil];
    
    CVReturn            error = kCVReturnSuccess;
    CGDirectDisplayID   displayID = CGMainDisplayID();
    
    error = CVDisplayLinkCreateWithCGDisplay(displayID, &mDisplayLink);
    if(error)
    {
        NSLog(@"DisplayLink created with error:%d", error);
        mDisplayLink = NULL;
        return;
    }
    error = CVDisplayLinkSetOutputCallback(mDisplayLink,
                                           myCVDisplayLinkOutputCallback, self);
}

- (void) emptyThreadEntry;
{
    // Exit right away.
}

- (void) surfaceNeedsUpdate: (NSNotification *) notification;
{
    [self update];
}

- (void) drawFrameInternal;
{
    NSOpenGLContext * currentContext = [self activeOpenGLContext];
    
    [self lockOpenGLLock];
    {
        [currentContext makeCurrentContext];
        [self drawFrame];
        [self flushBuffer: [self activeOpenGLContext]];
    }
    [self unlockOpenGLLock];
}

- (void) animationTimer;
{
    [self updateAnimation];
    [self drawFrameInternal];
}

- (BOOL) isDoubleBuffered: (NSOpenGLPixelFormat *) pixelFormat;
{
    long value;
    [pixelFormat getValues: &value
              forAttribute: NSOpenGLPFADoubleBuffer
          forVirtualScreen: 0];
    return value == 1? YES : NO;
}

- (void) flushBuffer: (NSOpenGLContext *) context;
{
    if (mDoubleBuffered)
        [context flushBuffer];
    else
        glFlush();
}

#pragma mark -
#pragma mark Full Screen

- (void) enterFullScreen;
{
    [self willEnterFullScreen];
    BOOL isAnimationRunning = [self isAnimationRunning];
    if (isAnimationRunning)
        [self stopAnimation];
    CGDisplayFadeReservationToken token = [self displayFadeOut];

    [self lockOpenGLLock];
    {
        
        // clear the current context (window)
        NSOpenGLContext *windowContext = [self openGLContext];
        [windowContext makeCurrentContext];
        glClear(GL_COLOR_BUFFER_BIT);
        [self flushBuffer: windowContext];
        [windowContext clearDrawable];
        
        // hide the cursor
        CGDisplayHideCursor(kCGDirectMainDisplay);
        // ask to black out all the attached displays
        CGCaptureAllDisplays();
        
        float oldHeight = CGDisplayPixelsHigh(kCGDirectMainDisplay);
        
        // change the display device resolution
        [self setFullScreenParametersForDisplay: kCGDirectMainDisplay
                                          width: mFullScreenWidth
                                         height: mFullScreenHeight
                                        refresh: 60];
        
        // find out the new device bounds
        mFullScreenRect.origin.x = 0; 
        mFullScreenRect.origin.y = 0; 
        mFullScreenRect.size.width = CGDisplayPixelsWide(kCGDirectMainDisplay); 
        mFullScreenRect.size.height = CGDisplayPixelsHigh(kCGDirectMainDisplay);
        
        // account for a workaround for fullscreen mode in AppKit
        // <http://www.idevgames.com/forum/showthread.php?s=&threadid=1461&highlight=mouse+location+cocoa>
        mFullScreenMouseOffset = oldHeight - mFullScreenRect.size.height + 1;
        
        // activate the fullscreen context and clear it
        mDoubleBuffered = [self isDoubleBuffered: mFullScreenPixelFormat];

        [mFullScreenOpenGLContext makeCurrentContext];
        glClear(GL_COLOR_BUFFER_BIT);
        [self flushBuffer: mFullScreenOpenGLContext];
        [mFullScreenOpenGLContext setFullScreen];
        
        [self update];
        
        [self didEnterFullScreen];
    }
    [self unlockOpenGLLock];
    
    [self displayFadeIn: token];    
    if (isAnimationRunning)
        [self startAnimation];
    
    // enter the manual event loop processing
    [self fullscreenEventLoop];
}

- (void) exitFullScreen;
{
    [self willExitFullScreen];
    BOOL isAnimationRunning = [self isAnimationRunning];
    if (isAnimationRunning)
        [self stopAnimation];
    CGDisplayFadeReservationToken token = [self displayFadeOut];
    
    [self lockOpenGLLock];
    {
        
        // clear the current context (fullscreen)
        [mFullScreenOpenGLContext makeCurrentContext];
        glClear(GL_COLOR_BUFFER_BIT);
        [self flushBuffer: mFullScreenOpenGLContext];
        [mFullScreenOpenGLContext clearDrawable];
        
        // ask the attached displays to return to normal operation
        CGReleaseAllDisplays();
        
        // show the cursor
        CGDisplayShowCursor(kCGDirectMainDisplay);
        
        // activate the window context and clear it
        NSOpenGLContext * windowContext = [self openGLContext];
        mDoubleBuffered = [self isDoubleBuffered: mPixelFormat];
        [windowContext setView: self];
        
        [windowContext makeCurrentContext];
        glClear(GL_COLOR_BUFFER_BIT);
        [self flushBuffer: windowContext];
        
        [self update];
        
        [self didExitFullScreen];
    }
    [self unlockOpenGLLock];
    
    [self displayFadeIn: token];
    if (isAnimationRunning)
        [self startAnimation];
}

- (void) fullscreenEventLoop;
{
    while (mFullScreen)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        // check for and process input events.
        NSDate * expiration = [NSDate distantPast];
        NSEvent * event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                             untilDate: expiration
                                                inMode: NSDefaultRunLoopMode
                                               dequeue: YES];
        if (event != nil)
            [NSApp sendEvent: event];
        [pool release];
    }
}

- (CGDisplayErr) setFullScreenParametersForDisplay: (CGDirectDisplayID) display
                                             width: (size_t) width 
                                            height: (size_t) height
                                           refresh: (CGRefreshRate) fps;
{
    CFDictionaryRef displayMode =
        CGDisplayBestModeForParametersAndRefreshRateWithProperty(
            display,
            CGDisplayBitsPerPixel(display),     
            width,                              
            height,                             
            fps,                                
            kCGDisplayModeIsSafeForHardware,
            NULL);
    return CGDisplaySwitchToMode(display, displayMode);
}

- (CGDisplayFadeReservationToken) displayFadeOut;
{
    CGDisplayFadeReservationToken token;
    CGDisplayErr err =
        CGAcquireDisplayFadeReservation(kCGMaxDisplayReservationInterval, &token); 
    if (err == CGDisplayNoErr)
    {
        CGDisplayFade(token, 0.5f, kCGDisplayBlendNormal,
                      kCGDisplayBlendSolidColor, 0, 0, 0, true); 
    }
    else
    { 
        token = kCGDisplayFadeReservationInvalidToken;
    }
    
    return token;
}

- (void) displayFadeIn: (CGDisplayFadeReservationToken) token;
{
    if (token != kCGDisplayFadeReservationInvalidToken)
    {
        CGDisplayFade(token, 0.5f, kCGDisplayBlendSolidColor,
                      kCGDisplayBlendNormal, 0, 0, 0, true); 
        CGReleaseDisplayFadeReservation(token); 
    }
}

@end
