//
//  DDCustomOpenGLView.m
//  DDCustomOpenGL
//
//  Created by Dave Dribin on 10/11/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DDCustomOpenGLView.h"

@interface DDCustomOpenGLView (Private)

- (void) initDisplayLink;
- (void) emptyThreadEntry;
- (void) surfaceNeedsUpdate: (NSNotification *) notification;
- (void) drawFrameInternal;
- (void) animationTimer;

#pragma mark -
#pragma mark "full screen"

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
    
    mFullScreenOpenGLContext = nil;
    mFullScreenPixelFormat = nil;
    mFullScreen = NO;
    
    mDisplayLock = [[NSRecursiveLock alloc] init];
    
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector(surfaceNeedsUpdate:)
               name: NSViewGlobalFrameDidChangeNotification
             object: self];


#if 0
    [NSTimer scheduledTimerWithTimeInterval: 1.0f/60.0f
                                     target: self
                                   selector: @selector(animationTimer)
                                   userInfo: nil
                                    repeats: YES];
#else
    [self initDisplayLink];
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
    [mDisplayLock release];
    
    mOpenGLContext = nil;
    mPixelFormat = nil;
    mFullScreenOpenGLContext = nil;
    mFullScreenPixelFormat = nil;
    mDisplayLock = nil;
    [super dealloc];
}

- (void) drawRect: (NSRect)rect
{
    [mDisplayLock lock];
    NSOpenGLContext * currentContext = [self currentOpenGLContext];
    {
        [currentContext makeCurrentContext];
        [self drawFrame];
        glFlush();
    }
    [mDisplayLock unlock];
}

- (void) updateAnimation;
{
}

- (void) drawFrame;
{
}

//=========================================================== 
//  openGLContext 
//=========================================================== 
- (NSOpenGLContext *) openGLContext
{
    [mDisplayLock lock];
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
    [mDisplayLock unlock];
    return mOpenGLContext;
}

- (void) setOpenGLContext: (NSOpenGLContext *) anOpenGLContext
{
    [mDisplayLock lock];
    {
        if (mOpenGLContext != anOpenGLContext)
        {
            [mOpenGLContext release];
            mOpenGLContext = [anOpenGLContext retain];
        }
    }
    [mDisplayLock unlock];
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
    [mDisplayLock lock];
    {
        if (mPixelFormat != aPixelFormat)
        {
            [mPixelFormat release];
            mPixelFormat = [aPixelFormat retain];
        }
    }
    [mDisplayLock unlock];
}

//=========================================================== 
//  fullScreenOpenGLContext 
//=========================================================== 
- (NSOpenGLContext *) fullScreenOpenGLContext
{
    [mDisplayLock lock];
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
    [mDisplayLock unlock];
    return mFullScreenOpenGLContext; 
}

- (void) setFullScreenOpenGLContext: (NSOpenGLContext *) aFullScreenOpenGLContext
{
    [mDisplayLock lock];
    {
        if (mFullScreenOpenGLContext != aFullScreenOpenGLContext)
        {
            [mFullScreenOpenGLContext release];
            mFullScreenOpenGLContext = [aFullScreenOpenGLContext retain];
        }
    }
    [mDisplayLock unlock];
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
    [mDisplayLock lock];
    {
        if (mFullScreenPixelFormat != aFullScreenPixelFormat)
        {
            [mFullScreenPixelFormat release];
            mFullScreenPixelFormat = [aFullScreenPixelFormat retain];
        }
    }
    [mDisplayLock unlock];
}

- (void) prepareOpenGL: (NSOpenGLContext *) context;
{
    // for overriding to initialize OpenGL state, occurs after context creation
}

- (void) setFullScreenWidth: (int) width height: (int) height;
{
    mFullScreenWidth = width;
    mFullScreenHeight = height;
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

- (NSOpenGLContext *) currentOpenGLContext;
{
    if (mFullScreen)
        return [self fullScreenOpenGLContext];
    else
        return [self openGLContext];
}

- (NSOpenGLPixelFormat *) currentPixelFormat;
{
    if (mFullScreen)
        return [self fullScreenPixelFormat];
    else
        return [self pixelFormat];
}

- (NSRect) currentBounds;
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
    [mDisplayLock lock];
    {
        // get context. will create if we don't have one yet
        NSOpenGLContext* context = [self currentOpenGLContext];
        
        // make sure we are ready to draw
        [super lockFocus];
        
        // when we are about to draw, make sure we are linked to the view
        if ([context view] != self)
        {
            [context setView: self];
        }
        
        // make us the current OpenGL context
        [context makeCurrentContext];
    }
    [mDisplayLock unlock];
}

// no reshape will be called since NSView does not export a specific reshape method

- (void) update
{
    [mDisplayLock lock];
    {
        NSOpenGLContext * context = [self currentOpenGLContext];
        
        if ([context view] == self)
        {
            [context update];
        }
    }
    [mDisplayLock unlock];
}

@end

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
    CVDisplayLinkStart(mDisplayLink);
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
    NSOpenGLContext * currentContext = [self currentOpenGLContext];
    
    [mDisplayLock lock];
    {
        [currentContext makeCurrentContext];
        [self drawFrame];
        [currentContext flushBuffer];
    }
    [mDisplayLock unlock];
}

- (void) animationTimer;
{
    [self drawFrameInternal];
}


#pragma mark -
#pragma mark "full screen"

- (void) enterFullScreen;
{
    CVDisplayLinkStop(mDisplayLink);
    CGDisplayFadeReservationToken token = [self displayFadeOut];

    [mDisplayLock lock];
    {
        
        // clear the current context (window)
        NSOpenGLContext *windowContext = [self openGLContext];
        [windowContext makeCurrentContext];
        glClear(GL_COLOR_BUFFER_BIT);
        [windowContext flushBuffer];
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
        [mFullScreenOpenGLContext makeCurrentContext];
        [mFullScreenOpenGLContext setFullScreen];
        glClear(GL_COLOR_BUFFER_BIT);
        [mFullScreenOpenGLContext flushBuffer];
        
        [self update];
        
        NSLog(@"Enter full screen");
    }
    [mDisplayLock unlock];
    
    [self displayFadeIn: token];    
    CVDisplayLinkStart(mDisplayLink);
    
    // enter the manual event loop processing
    [self fullscreenEventLoop];
}

- (void) exitFullScreen;
{
    CVDisplayLinkStop(mDisplayLink);
    CGDisplayFadeReservationToken token = [self displayFadeOut];
    
    [mDisplayLock lock];
    {
        
        // clear the current context (fullscreen)
        [mFullScreenOpenGLContext makeCurrentContext];
        glClear(GL_COLOR_BUFFER_BIT);
        [mFullScreenOpenGLContext flushBuffer];
        [mFullScreenOpenGLContext clearDrawable];
        
        // ask the attached displays to return to normal operation
        CGReleaseAllDisplays();
        
        // show the cursor
        CGDisplayShowCursor(kCGDirectMainDisplay);
        
        // activate the window context and clear it
        NSOpenGLContext * windowContext = [self openGLContext];
        [windowContext makeCurrentContext];
        glClear(GL_COLOR_BUFFER_BIT);
        [windowContext flushBuffer];
        
        [self update];
        
        NSLog(@"Exit full screen");
    }
    [mDisplayLock unlock];
    
    [self displayFadeIn: token];
    CVDisplayLinkStart(mDisplayLink);
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
