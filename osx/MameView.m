//
//  MameView.m
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import "MameView.h"
#import "MameController.h"
#import "MameRenderer.h"
#import "MameInputController.h"
#import "MameAudioController.h"
#import "MameTimingController.h"
#import "MameFileManager.h"
#import "MameConfiguration.h"

static NSRect centerNSSizeWithinRect(NSSize size, NSRect rect);

@interface MameView (Private)

- (BOOL) setupOpenGL;
- (NSOpenGLContext *) openGLContext;
- (NSOpenGLPixelFormat *) pixelFormat;
- (void)update;
- (void) surfaceNeedsUpdate: (NSNotification*) notification;

- (void) detectAcceleratedCoreImage;
- (void) initDisplayLink;

- (void) gameThread;
- (void) gameFinished;

#pragma mark -
#pragma mark "full screen"

- (NSOpenGLContext *) fullScreenContext;
- (NSOpenGLContext *) currentOpenGLContext;
- (void) enterFullScreen;
- (void) exitFullScreen;
- (void) fullscreenEventLoop;
- (CGDisplayErr) setFullScreenParametersForDisplay: (CGDirectDisplayID) display
                                             width: (size_t) width 
                                            height: (size_t) height
                                           refresh: (CGRefreshRate) fps;
- (CGDisplayFadeReservationToken) displayFadeOut;
- (void) displayFadeIn: (CGDisplayFadeReservationToken) token;


- (void) drawFrame;
- (void) drawFrameUsingCoreImage: (CVOpenGLTextureRef) frame;
- (void) drawFrameUsingOpenGL: (CVOpenGLTextureRef) frame;
- (void) updateVideo;

@end

NSString * MameViewNaturalSizeDidChange = @"NaturalSizeDidChange";

@implementation MameView

- (void) awakeFromNib
{
    [self setGame: nil];
    
    mRenderer = [[MameRenderer alloc] init];
    mInputController = [[MameInputController alloc] init];
    mAudioController = [[MameAudioController alloc] init];
    mTimingController = [[MameTimingController alloc] init];
    mFileManager = [[MameFileManager alloc] init];

    mRenderInCoreVideoThread = YES;
    mSyncToRefresh = NO;
    mMameLock = [[NSLock alloc] init];
    mMameIsRunning = NO;
    
    mDisplayLock = [[NSRecursiveLock alloc] init];
    mOpenGLInitialized = NO;
    mWindowedContext = nil;
    mWindowedPixelFormat = nil;
    
    mFullScreen = NO;
    mFullScreenContext = nil;
}

- (void) prepareOpenGL;
{
    glShadeModel(GL_SMOOTH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
}

- (void) createCIContext;
{
    [[self openGLContext] makeCurrentContext];
    /* Create CGColorSpaceRef */
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    /* Create CIContext */
    mCiContext = [[CIContext contextWithCGLContext:
        (CGLContextObj)[[self openGLContext] CGLContextObj]
                                       pixelFormat:(CGLPixelFormatObj)
        [[self pixelFormat] CGLPixelFormatObj]
                                           options:[NSDictionary dictionaryWithObjectsAndKeys:
                                               (id)colorSpace,kCIContextOutputColorSpace,
                                               (id)colorSpace,kCIContextWorkingColorSpace,nil]] retain];
    CGColorSpaceRelease(colorSpace);
}

- (CIContext *) ciContext;
{
    return mCiContext;
}

//=========================================================== 
//  renderInCoreVideoThread 
//=========================================================== 
- (BOOL) renderInCoreVideoThread
{
    return mRenderInCoreVideoThread;
}

- (void) setRenderInCoreVideoThread: (BOOL) flag
{
    mRenderInCoreVideoThread = flag;
}

- (NSSize) naturalSize;
{
    return mNaturalSize;
}

- (int) osd_init: (running_machine *) machine;
{
    NSLog(@"osd_init");
    [self setupOpenGL];
    [self fullScreenContext];
    
    mMachine = machine;
    [mInputController osd_init];
    [mAudioController osd_init];
    [mTimingController osd_init];
    
    mTarget = render_target_alloc(NULL, FALSE);
    
    render_target_set_orientation(mTarget, ROT0);
    render_target_set_layer_config(mTarget, LAYER_CONFIG_DEFAULT);
    render_target_set_view(mTarget, 0);

    INT32 minimumWidth;
    INT32 minimumHeight;
    render_target_get_minimum_size(mTarget, &minimumWidth, &minimumHeight);
    mNaturalSize = NSMakeSize(minimumWidth, minimumHeight);
    [[NSNotificationCenter defaultCenter] postNotificationName: MameViewNaturalSizeDidChange
                                                        object: self];
        
    [self createCIContext];
    [self detectAcceleratedCoreImage];
    
    NSLog(@"Use Core Image: %@", mCoreImageAccelerated? @"YES" : @"NO");
    NSLog(@"Render in Core Video thread: %@",
          mRenderInCoreVideoThread? @"YES" : @"NO");
    
    [mRenderer osd_init: [self openGLContext]
                 format: [self pixelFormat]
                   size: NSIntegralRect([self bounds]).size];
    
    [self initDisplayLink];
    
    return 0;
}

- (void) mameDidExit: (running_machine *) machine;
{
    mPrimitives = 0;
}

- (int) osd_update: (mame_time) emutime;
{
    // Drain the pool
    [mMamePool release];
    mMamePool = [[NSAutoreleasePool alloc] init];
    
    [self updateVideo];
    [mTimingController updateThrottle: emutime];
    
    // Open lock briefly to allow pending MAME calls
    [mMameLock unlock];
    [mMameLock lock];
    
    return 0;
}

- (BOOL) acceptsFirstResponder
{
    return YES;
}

- (void) keyDown: (NSEvent *) event
{
    [NSCursor setHiddenUntilMouseMoves: YES];
    [mInputController keyDown: event];
}

- (void) keyUp: (NSEvent *) event
{
    [mInputController keyUp: event];
}

- (void) flagsChanged: (NSEvent *) event
{
    [mInputController flagsChanged: event];
}

- (void) reshape
{
	NSOpenGLContext * currentContext;
    NSRect bounds;
    
    if (!mFullScreen)
    {
        currentContext = mWindowedContext;
        bounds = [self bounds];
        NSLog(@"Windowed bounds: %@", NSStringFromRect(bounds));
    }
    else
    {
        currentContext =  [self fullScreenContext];
        bounds = mFullScreenRect;
        NSLog(@"Full screen bounds: %@", NSStringFromRect(bounds));
    }
    
    [mDisplayLock lock];
	{
        float x = bounds.origin.x;
        float y = bounds.origin.y;
        float w = bounds.size.width;
        float h = bounds.size.height;
		[currentContext makeCurrentContext];
        glViewport(x, y, w, h);
        
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, w, 0, h, 0, 1);
        
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
	}
    [mDisplayLock unlock];
}

- (void)drawRect:(NSRect)aRect
{
    [mDisplayLock lock];
    [self drawFrame];
    [mDisplayLock unlock];
}

//=========================================================== 
//  game 
//=========================================================== 
- (NSString *) game
{
    return [[mGame retain] autorelease]; 
}

- (void) setGame: (NSString *) theGame
{
    if (mGame != theGame)
    {
        [mGame release];
        mGame = [theGame retain];
    }
    
    if (mGame != nil)
        mGameIndex = driver_get_index([mGame UTF8String]);
    else
        mGameIndex = -1;
}

- (BOOL) start;
{
    if (mGameIndex == -1)
        return NO;
    
    // osd_set_controller(self);
    osd_set_controller(self);
    osd_set_input_controller(mInputController);
    osd_set_audio_controller(mAudioController);
    osd_set_timing_controller(mTimingController);
    osd_set_file_manager(mFileManager);
    
    NSLog(@"Running %@", mGame);
    [NSThread detachNewThreadSelector: @selector(gameThread)
                             toTarget: self
                           withObject: nil];

    return YES;
}

- (void) stop;
{
    [mMameLock lock];
    mame_schedule_exit(mMachine);
    [mMameLock unlock];
}

- (void) togglePause;
{
    [mMameLock lock];
    if (mame_is_paused(mMachine))
        mame_pause(mMachine, FALSE);
    else
        mame_pause(mMachine, TRUE);
    [mMameLock unlock];
}

- (MameFileManager *) fileManager;
{
    return mFileManager;
}

- (BOOL) isRunning;
{
    return mMameIsRunning;
}

//=========================================================== 
//  throttled 
//=========================================================== 
- (BOOL) throttled
{
    @synchronized(self)
    {
        return [mTimingController throttled];
    }
}

- (void) setThrottled: (BOOL) flag
{
    @synchronized(self)
    {
        [mTimingController setThrottled: flag];
    }
}

//=========================================================== 
//  syncToRefresh 
//=========================================================== 
- (BOOL) syncToRefresh
{
    @synchronized(self)
    {
        return mSyncToRefresh;
    }
}

- (void) setSyncToRefresh: (BOOL) flag
{
    @synchronized(self)
    {
        mSyncToRefresh = flag;
        long swapInterval;
        if (mSyncToRefresh)
            swapInterval = 1;
        else
            swapInterval = 0;
        
        [mDisplayLock lock];
        [[self openGLContext] setValues: &swapInterval
                                forParameter: NSOpenGLCPSwapInterval];
        [mDisplayLock unlock];
    }
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
    [mDisplayLock lock];
    if (fullScreen && !mFullScreen)
    {
        if ([self fullScreenContext] != nil)
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
    [mDisplayLock unlock];
}

//=========================================================== 
//  audioEnabled 
//=========================================================== 
- (BOOL) audioEnabled
{
    return [mAudioController enabled];
}

- (void) setAudioEnabled: (BOOL) flag
{
    [mAudioController setEnabled: flag];
}

//=========================================================== 
//  filter 
//=========================================================== 
- (CIFilter *) filter
{
    return [[mFilter retain] autorelease]; 
}

- (void) setFilter: (CIFilter *) aFilter
{
    if (mFilter != aFilter)
    {
        [mFilter release];
        mFilter = [aFilter retain];
    }
}

@end

static NSRect centerNSSizeWithinRect(NSSize size, NSRect rect)
{
    float delta;
    if( NSHeight(rect) / NSWidth(rect) > size.height / size.width )
    {
        // rect is taller: fit width
        delta = rect.size.height - size.height * NSWidth(rect) / size.width;
        rect.size.height -= delta;
        rect.origin.y += delta/2;
    }
    else
    {
        // rect is wider: fit height
        delta = rect.size.width - size.width * NSHeight(rect) / size.height;
        rect.size.width -= delta;
        rect.origin.x += delta/2;
    }
    return rect;
}

@implementation MameView (Private)

- (BOOL) setupOpenGL;
{
	NSOpenGLPixelFormatAttribute colorSize = 32;
	NSOpenGLPixelFormatAttribute depthSize = 32;
	
    // pixel format attributes for the view based (non-fullscreen) NSOpenGLContext
    NSOpenGLPixelFormatAttribute attrsWin[] =
	{
        // specifying "NoRecovery" gives us a context that cannot fall back to the software renderer
		// this makes the view-based context a compatible with the fullscreen context,
		// enabling us to use the "shareContext" feature to share textures, display lists, and other OpenGL objects between the two
        NSOpenGLPFANoRecovery,
        // attributes common to fullscreen and window modes
        NSOpenGLPFAColorSize, colorSize,
        NSOpenGLPFADepthSize, depthSize,
        // NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0
    };
    
    mWindowedPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: attrsWin];
    if (mWindowedPixelFormat == nil)
        return NO;
        
    mWindowedContext = [[NSOpenGLContext alloc] initWithFormat: mWindowedPixelFormat
                                                  shareContext: nil];
    if (mWindowedContext == nil)
        return NO;
    NSLog(@"context: %@", mWindowedContext);
    [mWindowedContext makeCurrentContext];
    [self prepareOpenGL];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(surfaceNeedsUpdate:)
                                                 name: NSViewGlobalFrameDidChangeNotification
                                               object: self];
 
    
    mOpenGLInitialized = YES;
    return YES;
}

- (NSOpenGLContext *) openGLContext;
{
    return mWindowedContext;
}

- (NSOpenGLPixelFormat *) pixelFormat;
{
    return mWindowedPixelFormat;
}

- (void)update;
{
    if ([mWindowedContext view] == self) {
        [mWindowedContext update];
        [self reshape];
    }
}

- (void) surfaceNeedsUpdate: (NSNotification*) notification;
{
    [self update];
}

- (void) detectAcceleratedCoreImage;
{
    
    // This code fragment is from the VideoViewer sample code
    [[self openGLContext] makeCurrentContext];
    // CoreImage might be too slow if the current renderer doesn't support GL_ARB_fragment_program
    const GLubyte * glExtensions = glGetString(GL_EXTENSIONS);
    const GLubyte * extension = (const GLubyte *)"GL_ARB_fragment_program";
    mCoreImageAccelerated = gluCheckExtension(extension, glExtensions);
}

CVReturn static myCVDisplayLinkOutputCallback(CVDisplayLinkRef displayLink, 
                                       const CVTimeStamp *inNow, 
                                       const CVTimeStamp *inOutputTime, 
                                       CVOptionFlags flagsIn, 
                                       CVOptionFlags *flagsOut, 
                                       void *displayLinkContext)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    MameView * view = (MameView *) displayLinkContext;
    [view drawFrame];
    [pool release];
    return kCVReturnSuccess;
}

- (void) initDisplayLink;
{
    mPrimitives = 0;
        
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
    mFrameStartTime = [mTimingController osd_cycles];
    mFramesDisplayed = 0;
    mFramesRendered = 0;
    CVDisplayLinkStart(mDisplayLink);
}

- (void) gameThread
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    [mMameLock lock];
    mMamePool = [[NSAutoreleasePool alloc] init];
    mMameIsRunning = YES;
    run_game(mGameIndex);
    mMameIsRunning = NO;
    [mMamePool release];
    [mMameLock unlock];
    
    cycles_t cps = [mTimingController osd_cycles_per_second];
    NSLog(@"Average FPS displayed: %f (%qi frames)\n",
          (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesDisplayed,
          mFramesDisplayed);
    NSLog(@"Average FPS rendered: %f (%qi frames)\n",
          (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesRendered,
          mFramesRendered);
    

    [self performSelectorOnMainThread: @selector(gameFinished)
                           withObject: nil
                        waitUntilDone: NO];
    
    [pool release];
}

- (void) gameFinished
{
   [NSApp terminate: nil];
}

#pragma mark -
#pragma mark "full screen"

- (NSOpenGLContext *) fullScreenContext;
{
    if (mFullScreenContext == nil)
    {
        NSOpenGLPixelFormat * currentFormat = [self pixelFormat];
        long colorSize;
        [currentFormat getValues: &colorSize
                    forAttribute: NSOpenGLPFAColorSize
                forVirtualScreen: 0];
        long depthSize;
        [currentFormat getValues: &depthSize
                    forAttribute: NSOpenGLPFAColorSize
                forVirtualScreen: 0];
        long doubleBuffer;
        [currentFormat getValues: &doubleBuffer
                    forAttribute: NSOpenGLPFADoubleBuffer
                forVirtualScreen: 0];
        
        
//        NSOpenGLPixelFormatAttribute colorSize = 24;
//        NSOpenGLPixelFormatAttribute depthSize = 16;

		// pixel format attributes for the fullscreen NSOpenGLContext
		NSOpenGLPixelFormatAttribute attrsFull[] =
        {
            // specify that we want a fullscreen OpenGL context.
            NSOpenGLPFAFullScreen,
            // we may be on a multi-display system (and each screen may be driven by a different renderer), so we need to specify which screen we want to take over. 
            // in this case, we'll specify the main screen.
            NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
            // attributes common to fullscreen and window modes
            NSOpenGLPFAColorSize, colorSize,
            NSOpenGLPFADepthSize, depthSize,
            // NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAAccelerated,
            0
        };
		
         mFullScreenPixelFormat =
            [[NSOpenGLPixelFormat alloc] initWithAttributes: attrsFull];
		
		// we need a separate OpenGL context for full-screen only mode
		// notice that we pass this view's OpenGL context as the shared one
		mFullScreenContext =
            [[NSOpenGLContext alloc] initWithFormat: mFullScreenPixelFormat
                                       shareContext: [self openGLContext]];
        NSLog(@"mFullScreenContext: %@", mFullScreenContext);
		
		const long swapInterval = 1; // request beam sync
		[mFullScreenContext setValues: &swapInterval
                         forParameter: NSOpenGLCPSwapInterval];
        
        [mFullScreenContext makeCurrentContext];
        [self prepareOpenGL];
    }
    
    return mFullScreenContext;
}

- (NSOpenGLContext *) currentOpenGLContext;
{
    if (mFullScreen)
        return [self fullScreenContext];
    else
        return [self openGLContext];
}

- (void) enterFullScreen;
{
	[mDisplayLock lock];
	{
        CVDisplayLinkStop(mDisplayLink);
		// create nice fade in effect
		CGDisplayFadeReservationToken token = [self displayFadeOut];

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
		
        NSSize naturalSize = [self naturalSize];
		// change the display device resolution
		[self setFullScreenParametersForDisplay: kCGDirectMainDisplay
                                          width: naturalSize.width * 2
                                         height: naturalSize.height * 2
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
		[mFullScreenContext makeCurrentContext];
        [self prepareOpenGL];
		[mFullScreenContext setFullScreen];
		glClear(GL_COLOR_BUFFER_BIT);
		[mFullScreenContext flushBuffer];
        
		[self reshape];
		
        [mRenderer release];
        mRenderer = [[MameRenderer alloc] init];
        [mRenderer osd_init: mFullScreenContext
                     format: mFullScreenPixelFormat
                       size: mFullScreenRect.size];
        NSLog(@"Enter full screen");
        
		[self displayFadeIn: token];	
        CVDisplayLinkStart(mDisplayLink);
	}
	[mDisplayLock unlock];
	
	// enter the manual event loop processing
	[self fullscreenEventLoop];
}

- (void) exitFullScreen;
{
	[mDisplayLock lock];
	{
        CVDisplayLinkStop(mDisplayLink);
		// create nice fade in effect
		CGDisplayFadeReservationToken token = [self displayFadeOut];
		
		// clear the current context (fullscreen)
		[mFullScreenContext makeCurrentContext];
		glClear(GL_COLOR_BUFFER_BIT);
		[mFullScreenContext flushBuffer];
		[mFullScreenContext clearDrawable];
		
		// ask the attached displays to return to normal operation
		CGReleaseAllDisplays();
        
		// show the cursor
		CGDisplayShowCursor(kCGDirectMainDisplay);
		
		// activate the window context and clear it
		NSOpenGLContext * windowContext = [self openGLContext];
		[windowContext makeCurrentContext];
		glClear(GL_COLOR_BUFFER_BIT);
		[windowContext flushBuffer];
		
		[self reshape];

        [mRenderer release];
        mRenderer = [[MameRenderer alloc] init];
        [mRenderer osd_init: [self openGLContext]
                     format: [self pixelFormat]
                       size: NSIntegralRect([self bounds]).size];
        NSLog(@"Exit full screen");
        
		[self displayFadeIn: token];
        CVDisplayLinkStart(mDisplayLink);
	}
	[mDisplayLock unlock];
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


#pragma mark -
#pragma mark "frame drawing"

- (void) drawFrame;
{
    [mDisplayLock lock];
    if (!mOpenGLInitialized)
    {
        if (![self setupOpenGL])
            return;
    }
    
    NSOpenGLContext * currentContext = [self currentOpenGLContext];
    
    if (mRenderInCoreVideoThread)
    {
        const render_primitive_list * primitives = 0;
        NSSize renderSize;
        BOOL skipFrame = NO;
        @synchronized(self)
        {
            primitives = mPrimitives;
            renderSize = mRenderSize;
        }
        
        if (primitives == 0)
        {
            skipFrame = YES;
        }
        else
        {
            osd_lock_acquire(primitives->lock);
            if (primitives->head == NULL)
            {
                skipFrame = YES;
            }
            else
            {
                [mRenderer renderFrame: primitives
                              withSize: renderSize];
                skipFrame = NO;
            }
            osd_lock_release(primitives->lock);
        }
        
        if (skipFrame)
        {
            [mDisplayLock unlock];
            return;
        }
    }
    
    [currentContext makeCurrentContext];
    
    if (mRenderInCoreVideoThread)
        glClearColor(1.0, 0.0, 0.0, 0.0);
    else
        glClearColor(1.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CVOpenGLTextureRef frame = [mRenderer currentFrameTexture];
    if (NO) //  (mCoreImageAccelerated)
        [self drawFrameUsingCoreImage: frame];
    else
        [self drawFrameUsingOpenGL: frame];
    
    glFlush();
    
    mFramesDisplayed++;
    mFrameEndTime = [mTimingController osd_cycles];
    
    [mDisplayLock unlock];
}

- (void) drawFrameUsingCoreImage: (CVOpenGLTextureRef) frame;
{
    CIImage * inputImage = [CIImage imageWithCVImageBuffer: frame];
    CIContext * ciContext = [self ciContext];

    CIImage * imageToDraw = inputImage;
    if (mFilter != nil)
    {
        if (mMoveInputCenter)
        {
            inputCenterX += 2;
            if (inputCenterX > [self bounds].size.width)
                inputCenterX = 0;
            
            [mFilter setValue: [CIVector vectorWithX: inputCenterX Y: inputCenterY]  
                       forKey: @"inputCenter"];
        }
        
        [mFilter setValue: inputImage forKey:@"inputImage"];
        imageToDraw = [mFilter valueForKey: @"outputImage"];
    }
    CGRect imageRect = [imageToDraw extent];
    
    NSRect bounds;
        bounds = [self bounds];
    NSRect nsDest = centerNSSizeWithinRect(mRenderSize, bounds);
    CGRect destRect = CGRectMake(nsDest.origin.x, nsDest.origin.y,
                                 nsDest.size.width, nsDest.size.height);
    [ciContext drawImage: imageToDraw
                  inRect: *(CGRect *) &nsDest
                fromRect: imageRect];
}

- (void) drawFrameUsingOpenGL: (CVOpenGLTextureRef) frame;
{
    GLfloat vertices[4][2];
    GLfloat texCoords[4][2];
    
    // Configure OpenGL to get vertex and texture coordinates from our two arrays
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
    
    // Specify video rectangle vertices counter-clockwise from the
    // origin (lower left) after centering
    NSRect bounds;
    if (!mFullScreen)
    {
        bounds = centerNSSizeWithinRect(mRenderSize, [self bounds]);
    }
    else
    {
        bounds = mFullScreenRect;
        float x = bounds.origin.x;
        float y = bounds.origin.y;
        float w = bounds.size.width;
        float h = bounds.size.height;

        glViewport(x, y, w, h);
        
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, w, 0, h, 0, 1);
        
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
    }

    vertices[0][0] = bounds.origin.x;
    vertices[0][1] = bounds.origin.y;
    vertices[1][0] = NSMaxX(bounds);
    vertices[1][1] = bounds.origin.y;
    vertices[2][0] = NSMaxX(bounds);
    vertices[2][1] = NSMaxY(bounds);
    vertices[3][0] = bounds.origin.x;
    vertices[3][1] = NSMaxY(bounds);
    
    GLenum textureTarget = CVOpenGLTextureGetTarget(frame);
    
    // Make sure the correct texture target is enabled
    if (textureTarget != mLastTextureTarget)
    {
        glDisable(mLastTextureTarget);
        mLastTextureTarget = textureTarget;
        glEnable(mLastTextureTarget);
    }
    
    glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    // Get the current texture's coordinates, bind the texture, and draw our rectangle
    CVOpenGLTextureGetCleanTexCoords(frame, texCoords[0], texCoords[1], texCoords[2], texCoords[3]);
    if (mFullScreen)
    {
        NSLog(@"texCoords (%f, %f), (%f, %f), (%f, %f), (%f, %f)",
              texCoords[0][0], texCoords[0][1],
              texCoords[1][0], texCoords[1][1],
              texCoords[2][0], texCoords[2][1],
              texCoords[3][0], texCoords[3][1]);
              
    }
    glBindTexture(mLastTextureTarget, CVOpenGLTextureGetName(frame));
    glDrawArrays(GL_QUADS, 0, 4);
}

- (void) updateVideo;
{
    NSSize renderSize = centerNSSizeWithinRect(mNaturalSize, [self bounds]).size;
    
    if (mRenderInCoreVideoThread)
    {
        render_target_set_bounds(mTarget, renderSize.width, renderSize.height, 0.0);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        @synchronized(self)
        {
            mRenderSize = renderSize;
            mPrimitives = primitives;
        }
    }
    else
    {
        [mDisplayLock lock];
        
        render_target_set_bounds(mTarget, renderSize.width, renderSize.height, 0.0);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        [mRenderer renderFrame: primitives
                      withSize: renderSize];
        mRenderSize = renderSize;
        
        [mDisplayLock unlock];
    }
    
    if (!mame_is_paused(mMachine))
        mFramesRendered++;
}

@end

