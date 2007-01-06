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

#import "MameView.h"
#import "MameController.h"
#import "MameRenderer.h"
#import "MameInputController.h"
#import "MameAudioController.h"
#import "MameTimingController.h"
#import "MameFileManager.h"
#import "MameConfiguration.h"
#import "MameFilter.h"
#import "NXLog.h"


@interface MameView (Private)

- (BOOL) isCoreImageAccelerated;
- (BOOL) hasMultipleCPUs;

- (void) gameThread;
- (void) gameFinished: (NSNumber *) exitStatus;

#pragma mark -
#pragma mark "Notifications and Delegates"

- (void) sendMameWillStartGame;
- (void) sendMameDidFinishGame;

- (NSString *) formatOutputMessage: (const char *) utf8Format
                         arguments: (va_list) argptr;

#pragma mark -
#pragma mark "Frame Drawing"

- (void) drawFrame;
- (void) drawFrameUsingCoreImage: (CVOpenGLTextureRef) frame
                          inRect: (NSRect) destRect;
- (void) drawFrameUsingOpenGL: (CVOpenGLTextureRef) frame
                       inRect: (NSRect) destRect;
- (void) updateVideo;

- (NSRect) stretchNSSize: (NSSize) size withinRect: (NSRect) rect;
- (NSRect) centerNSSize: (NSSize) size withinRect: (NSRect) rect;

- (void) updatePixelAspectRatio;
- (float) aspectRatioForDisplay: (CGDirectDisplayID) displayId;

@end

NSString * MameWillStartGame = @"MameWillStartGame";
NSString * MameDidFinishGame = @"MameDidFinishGame";
NSString * MameExitStatusKey = @"MameExitStatus";

@implementation MameView

+ (void) initialize
{
    [self setKeys: [NSArray arrayWithObject: @"indexOfCurrentEffect"]
          triggerChangeNotificationsForDependentKey: @"audioEffectFactoryPresets"];
    [self setKeys: [NSArray arrayWithObject: @"indexOfCurrentEffect"]
          triggerChangeNotificationsForDependentKey: @"indexOfCurrentFactoryPreset"];
}

- (id) initWithFrame: (NSRect) frameRect
{
    // pixel format attributes for the view based (non-fullscreen) NSOpenGLContext
    NSOpenGLPixelFormatAttribute windowedAttributes[] =
    {
        // specifying "NoRecovery" gives us a context that cannot fall back to the software renderer
        // this makes the view-based context a compatible with the fullscreen context,
        // enabling us to use the "shareContext" feature to share textures, display lists, and other OpenGL objects between the two
        NSOpenGLPFANoRecovery,
        // attributes common to fullscreen and window modes
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0
    };
    NSOpenGLPixelFormat * windowedPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: windowedAttributes];
    [windowedPixelFormat autorelease];
    
    self = [super initWithFrame: frameRect pixelFormat: windowedPixelFormat];
    if (self == nil)
        return nil;
    
    // pixel format attributes for the full screen NSOpenGLContext
    NSOpenGLPixelFormatAttribute fullScreenAttributes[] =
    {
        // specify that we want a fullscreen OpenGL context
        NSOpenGLPFAFullScreen,
        // we may be on a multi-display system (and each screen may be driven
        // by a different renderer), so we need to specify which screen we want
        // to take over. 
        // in this case, we'll specify the main screen.
        NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
        // attributes common to fullscreen and window modes
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0
    };
    NSOpenGLPixelFormat * fullScreenPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: fullScreenAttributes];
    [fullScreenPixelFormat autorelease];
    [self setFullScreenPixelFormat: fullScreenPixelFormat];
    [self setFadeTime: 0.25f];
    
    mKeepAspectRatio = YES;
    mClearToRed = NO;
    mFrameStartTime = 0;
    [self setFrameRenderingOption: [self frameRenderingOptionDefault]];
    [self setRenderInCoreVideoThread: [self renderInCoreVideoThreadDefault]];
    
    mRenderer = [[MameRenderer alloc] init];
    mInputController = [[MameInputController alloc] init];
    mAudioController = [[MameAudioController alloc] init];
    mTimingController = [[MameTimingController alloc] init];
    mFileManager = [[MameFileManager alloc] init];
    
    return self;
}

- (void) awakeFromNib
{
    [self setGame: nil];

    // osd_set_controller(self);
    osd_set_controller(self);
    osd_set_input_controller(mInputController);
    osd_set_audio_controller(mAudioController);
    osd_set_timing_controller(mTimingController);
    osd_set_file_manager(mFileManager);

    mSyncToRefresh = NO;
    mMameLock = [[NSLock alloc] init];
    mMameIsRunning = NO;
}

- (void) dealloc
{
    NSNotificationCenter * center = [NSNotificationCenter defaultCenter];
    
    if (mDelegate != nil)
        [center removeObserver: mDelegate name: nil object: self];
    
    [super dealloc];
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

- (void) prepareOpenGL: (NSOpenGLContext *) context;
{
    long swapInterval;
    swapInterval = 1;
    
    [context setValues: &swapInterval
                       forParameter: NSOpenGLCPSwapInterval];

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

    mFullScreenCiContext = [[CIContext contextWithCGLContext:
        (CGLContextObj)[[self fullScreenOpenGLContext] CGLContextObj]
                                       pixelFormat:(CGLPixelFormatObj)
        [[self fullScreenPixelFormat] CGLPixelFormatObj]
                                           options:[NSDictionary dictionaryWithObjectsAndKeys:
                                               (id)colorSpace,kCIContextOutputColorSpace,
                                               (id)colorSpace,kCIContextWorkingColorSpace,nil]] retain];
    
    CGColorSpaceRelease(colorSpace);
}

- (CIContext *) ciContext;
{
    if ([self fullScreen])
        return mFullScreenCiContext;
    else
        return mCiContext;
}

- (MameFrameRenderingOption) frameRenderingOption;
{
    return mFrameRenderingOption;
}

- (void) setFrameRenderingOption:
    (MameFrameRenderingOption) frameRenderingOption;
{
    mFrameRenderingOption = frameRenderingOption;
}

- (MameFrameRenderingOption) frameRenderingOptionDefault;
{
    if ([self isCoreImageAccelerated])
        return MameRenderFrameInCoreImage;
    else
        return MameRenderFrameInOpenGL;
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

- (BOOL) renderInCoreVideoThreadDefault;
{
    if ([self hasMultipleCPUs])
        return YES;
    else
        return NO;
}

//=========================================================== 
//  clearToRed 
//=========================================================== 
- (BOOL) clearToRed;
{
    return mClearToRed;
}

- (void) setClearToRed: (BOOL) clearToRed;
{
    mClearToRed = clearToRed;
}

- (NSSize) naturalSize;
{
    return mNaturalSize;
}

- (NSSize) optimalSize;
{
    return mOptimalSize;
}

- (BOOL) keepAspectRatio;
{
    return mKeepAspectRatio;
}

- (void) setKeepAspectRatio: (BOOL) keepAspectRatio;
{
    mKeepAspectRatio = keepAspectRatio;
}

- (int) osd_init: (running_machine *) machine;
{
    NXLogInfo(@"osd_init");
    
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
    [self updatePixelAspectRatio];
    INT32 visibleWidth, visibleHeight;
    render_target_compute_visible_area(mTarget, minimumWidth, minimumHeight,
                                       mPixelAspectRatio, ROT0,
                                       &visibleWidth, &visibleHeight);
    NXLogInfo(@"Aspect ratio: %f, Minimum size: %dx%d, visible size: %dx%d",
              mPixelAspectRatio, minimumWidth, minimumHeight, visibleWidth,
              visibleHeight);
    mNaturalSize = NSMakeSize(visibleWidth, visibleHeight);
    
    mOptimalSize = mNaturalSize;
    if ((mOptimalSize.width < 640) && (mOptimalSize.height < 480))
    {
        mOptimalSize.width *=2;
        mOptimalSize.height *= 2;
    }
    
    [self setFullScreenWidth: mOptimalSize.width height: mOptimalSize.height];
    mFullScreenSize = NSMakeSize([self fullScreenWidth], 
                                 [self fullScreenHeight]);

    [[NSNotificationCenter defaultCenter] postNotificationName: MameWillStartGame
                                                        object: self];
        
    [self createCIContext];
    
    NSString * frameRendering;
    switch (mFrameRenderingOption)
    {
        case MameRenderFrameInOpenGL:
            frameRendering = @"OpenGL";
            break;
            
        case MameRenderFrameInCoreImage:
            frameRendering = @"Core Image";
            break;
            
        default:
            frameRendering = @"Unknown";
    }
    NXLogInfo(@"Render frames in: %@", frameRendering);
    NXLogInfo(@"Render in Core Video thread: %@",
              mRenderInCoreVideoThread? @"YES" : @"NO");
    
    [mRenderer osd_init: [self openGLContext]
                 format: [self pixelFormat]
                   size: NSIntegralRect([self bounds]).size];
    
    [self startAnimation];
    
    return 0;
}

- (void) mameDidExit: (running_machine *) machine;
{
    mPrimitives = 0;
    [self stopAnimation];
}

- (void) mameDidPause: (running_machine *) machine
                puase: (int) pause; 
{
    [mAudioController setPaused: ((pause == 1)? YES : NO)];
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

- (void) resize
{
    NSRect bounds = [self activeBounds];
    
	{
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
}


//=========================================================== 
//  game 
//=========================================================== 
- (NSString *) game
{
    return [[mGame retain] autorelease]; 
}

- (BOOL) setGame: (NSString *) theGame
{
    if (mGame != theGame)
    {
        [mGame release];
        mGame = [theGame retain];
    }
    
    if (mGame != nil)
    {
        mGameIndex = driver_get_index([mGame UTF8String]);
        if (mGameIndex != -1)
            return YES;
        else
            return NO;
    }
    else
    {
        mGameIndex = -1;
        return NO;
    }
}

- (int) gameIndex;
{
    return mGameIndex;
}

- (NSString *) gameDescription;
{
    if (mGameIndex >= 0)
        return [NSString stringWithUTF8String: drivers[mGameIndex]->description];
    else
        return @"";
}


- (BOOL) start;
{
    if (mGameIndex == -1)
        return NO;
    
    NXLogInfo(@"Running %@", mGame);
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
    if (!mMameIsRunning)
        return;
    [mMameLock lock];
    if (mame_is_paused(mMachine))
        mame_pause(mMachine, FALSE);
    else
        mame_pause(mMachine, TRUE);
    [mMameLock unlock];
}

- (BOOL) pause: (BOOL) pause
{
    if (!mMameIsRunning)
        return;
    [mMameLock lock];
    BOOL isPaused = mame_is_paused(mMachine);
    mame_pause(mMachine, pause);
    [mMameLock unlock];
    return isPaused;
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

#pragma mark -
#pragma mark Audio

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

- (BOOL) audioEffectEnabled;
{
    return [mAudioController effectEnabled];
}

- (void) setAudioEffectEnabled: (BOOL) flag;
{
    [mAudioController setEffectEnabled: flag];
}

- (NSArray *) audioEffectComponents;
{
    return [mAudioController effectComponents];
}

- (unsigned) indexOfCurrentEffect;
{
    return [mAudioController indexOfCurrentEffect];
}

- (void) setIndexOfCurrentEffect: (unsigned) indexOfCurrentEffect;
{
    [mAudioController setIndexOfCurrentEffect: indexOfCurrentEffect];
}

- (NSView *) createAudioEffectViewWithSize: (NSSize) size;
{
    return [mAudioController createEffectViewWithSize: size];
}

- (NSArray *) audioEffectFactoryPresets;
{
    return [mAudioController effectFactoryPresets];
}

- (unsigned) indexOfCurrentFactoryPreset;
{
    return [mAudioController indexOfCurrentFactoryPreset];
}

- (void) setIndexOfCurrentFactoryPreset: (unsigned) index;
{
    [mAudioController setIndexOfCurrentFactoryPreset: index];
}

- (float) audioCpuLoad;
{
    return [mAudioController cpuLoad];
}

#pragma mark -

- (BOOL) linearFilter;
{
    return [mRenderer linearFilter];
}

- (void) setLinearFilter: (BOOL) linearFilter;
{
    [mRenderer setLinearFilter: linearFilter];
}

//=========================================================== 
//  filter 
//=========================================================== 
- (MameFilter *) filter
{
    return [[mFilter retain] autorelease]; 
}

- (void) setFilter: (MameFilter *) aFilter
{
    if (mFilter != aFilter)
    {
        [mFilter release];
        mFilter = [aFilter retain];
    }
}

#pragma mark -
#pragma mark OS Dependent API

- (int) osd_update: (mame_time) emutime;
{
    // Drain the pool
    [mMamePool release];
    mMamePool = [[NSAutoreleasePool alloc] init];
    
    [self updateVideo];
    if (mFrameStartTime == 0)
        mFrameStartTime = [mTimingController osd_cycles];
    [mTimingController updateThrottle: emutime];
    [mTimingController updateAutoFrameSkip];
    
    // Open lock briefly to allow pending MAME calls
    [mMameLock unlock];
    [mMameLock lock];
    
    return [mTimingController skipFrame];
}

- (void) osd_output_error: (const char *) utf8Format
                arguments: (va_list) argptr;
{
    if ([mDelegate respondsToSelector: @selector(mameErrorMessage:)])
    {
        NSString * message = [self formatOutputMessage: utf8Format
                                             arguments: argptr];
        [mDelegate performSelectorOnMainThread: @selector(mameErrorMessage:)
                                    withObject: message
                                 waitUntilDone: NO];
    }
}

- (void) osd_output_warning: (const char *) utf8Format
                  arguments: (va_list) argptr;
{
    if ([mDelegate respondsToSelector: @selector(mameWarningMessage:)])
    {
        NSString * message = [self formatOutputMessage: utf8Format
                                             arguments: argptr];
        [mDelegate performSelectorOnMainThread: @selector(mameWarningMessage:)
                                    withObject: message
                                 waitUntilDone: NO];
    }
}

- (void) osd_output_info: (const char *) utf8Format
               arguments: (va_list) argptr;
{
    if ([mDelegate respondsToSelector: @selector(mameInfoMessage:)])
    {
        NSString * message = [self formatOutputMessage: utf8Format
                                             arguments: argptr];
        [mDelegate performSelectorOnMainThread: @selector(mameInfoMessage:)
                                    withObject: message
                                 waitUntilDone: NO];
    }
}

- (void) osd_output_debug: (const char *) utf8Format
                arguments: (va_list) argptr;
{
    if ([mDelegate respondsToSelector: @selector(mameDebugMessage:)])
    {
        NSString * message = [self formatOutputMessage: utf8Format
                                             arguments: argptr];
        [mDelegate performSelectorOnMainThread: @selector(mameDebugMessage:)
                                    withObject: message
                                 waitUntilDone: NO];
    }
}

- (void) osd_output_log: (const char *) utf8Format
              arguments: (va_list) argptr;
{
    if ([mDelegate respondsToSelector: @selector(mameLogMessage:)])
    {
        NSString * message = [self formatOutputMessage: utf8Format
                                             arguments: argptr];
        [mDelegate performSelectorOnMainThread: @selector(mameLogMessage:)
                                    withObject: message
                                 waitUntilDone: NO];
    }
}


- (id) delegagte;
{
    return mDelegate;
}

- (void) setDelegate: (id) delegate;
{
    NSNotificationCenter * center = [NSNotificationCenter defaultCenter];

    if (mDelegate != nil)
        [center removeObserver: mDelegate name: nil object: self];
        
    mDelegate = delegate;
    
    // repeat  the following for each notification
    if ([mDelegate respondsToSelector: @selector(mameWillStartGame:)])
    {
        [center addObserver: mDelegate selector: @selector(mameWillStartGame:)
                       name: MameWillStartGame object: self];
    }
    if ([mDelegate respondsToSelector: @selector(mameDidFinishGame:)])
    {
        [center addObserver: mDelegate selector: @selector(mameDidFinishGame:)
                       name: MameDidFinishGame object: self];
    }
}

@end

@implementation MameView (Private)

- (BOOL) isCoreImageAccelerated;
{
    
    // This code fragment is from the VideoViewer sample code
    [[self openGLContext] makeCurrentContext];
    // CoreImage might be too slow if the current renderer doesn't support GL_ARB_fragment_program
    const GLubyte * glExtensions = glGetString(GL_EXTENSIONS);
    const GLubyte * extension = (const GLubyte *)"GL_ARB_fragment_program";
    return gluCheckExtension(extension, glExtensions);
}

- (BOOL) hasMultipleCPUs;
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	host_info(mach_host_self(), HOST_BASIC_INFO, 
			  (host_info_t)&hostInfo, &infoCount);
    if (hostInfo.avail_cpus > 1)
        return YES;
    else
        return NO;
}

- (void) gameThread
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    [mMameLock lock];
    mMamePool = [[NSAutoreleasePool alloc] init];
    mMameIsRunning = YES;
    int exitStatus = run_game(mGameIndex);
    mMameIsRunning = NO;
    [mMamePool release];
    [mMameLock unlock];
    
    cycles_t cps = [mTimingController osd_cycles_per_second];
    NXLogInfo(@"Average FPS displayed: %f (%qi frames)\n",
              (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesDisplayed,
              mFramesDisplayed);
    NXLogInfo(@"Average FPS rendered: %f (%qi frames)\n",
              (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesRendered,
              mFramesRendered);
    [mTimingController gameFinished];

    [self performSelectorOnMainThread: @selector(gameFinished:)
                           withObject: [NSNumber numberWithInt: exitStatus]
                        waitUntilDone: NO];
    
    [pool release];
}

- (void) gameFinished: (NSNumber *) exitStatus;
{
    NSDictionary * userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        exitStatus, MameExitStatusKey,
        nil];
    [[NSNotificationCenter defaultCenter] postNotificationName: MameDidFinishGame
                                                        object: self
                                                      userInfo: userInfo];
}

- (void) willEnterFullScreen;
{
    mUnpauseOnFullScreenTransition = [self pause: YES];
}

- (void) willExitFullScreen;
{
    mUnpauseOnFullScreenTransition = [self pause: YES];
}

- (void) didEnterFullScreen;
{
    [self pause: mUnpauseOnFullScreenTransition];
}

- (void) didExitFullScreen;
{
    [self pause: mUnpauseOnFullScreenTransition];
}


#pragma mark -
#pragma mark "Notifications and Delegates"

- (void) sendMameWillStartGame;
{
    [[NSNotificationCenter defaultCenter] postNotificationName: MameWillStartGame
                                                        object: self];
}

- (void) sendMameDidFinishGame;
{
}

- (NSString *) formatOutputMessage: (const char *) utf8Format
                         arguments: (va_list) argptr;
{
    NSString * format = [NSString stringWithUTF8String: utf8Format];
    return [[[NSString alloc] initWithFormat: format
                                   arguments: argptr] autorelease];
}

#pragma mark -
#pragma mark "Frame Drawing"

- (NSRect) stretchNSSize: (NSSize) size withinRect: (NSRect) rect;
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
    rect = NSIntegralRect(rect);
    return rect;
}

- (NSRect) centerNSSize: (NSSize) size withinRect: (NSRect) rect;
{
    rect.origin.x = (rect.size.width - size.width) / 2;
    rect.origin.y = (rect.size.height - size.height) / 2;
    rect.size = size;
    return rect;
}

- (void) drawFrame;
{
    [self resize];
    
    NSOpenGLContext * currentContext = [self activeOpenGLContext];
    
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
            return;
        }
    }
    
    [currentContext makeCurrentContext];
    
    if (mClearToRed)
        glClearColor(1.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CVOpenGLTextureRef frame = [mRenderer currentFrameTexture];
    if (frame == NULL)
        return;
    
    NSRect currentBounds = [self activeBounds];
    NSRect destRect;
    if ([self fullScreen])
    {
        destRect = [self centerNSSize: mRenderSize withinRect: currentBounds];
    }
    else
        destRect = [self stretchNSSize: mRenderSize withinRect: currentBounds];

    if (mFrameRenderingOption == MameRenderFrameInCoreImage)
        [self drawFrameUsingCoreImage: frame inRect: destRect];
    else
        [self drawFrameUsingOpenGL: frame inRect: destRect];
    
    mFramesDisplayed++;
    mFrameEndTime = [mTimingController osd_cycles];
}

- (void) drawFrameUsingCoreImage: (CVOpenGLTextureRef) frame
                          inRect: (NSRect) destRect;
{
    CIImage * frameImage = [CIImage imageWithCVImageBuffer: frame];
    CIContext * ciContext = [self ciContext];

    CGRect frameRect = [frameImage extent];
    NSSize frameSize = NSMakeSize(frameRect.size.width, frameRect.size.height);
    if (mFilter != nil)
    {
        frameImage = [mFilter filterFrame: frameImage size: frameSize];
    }
    frameRect = [frameImage extent];
    
    [ciContext drawImage: frameImage
                  inRect: *(CGRect *) &destRect
                fromRect: frameRect];
}

- (void) drawFrameUsingOpenGL: (CVOpenGLTextureRef) frame
                       inRect: (NSRect) destRect;
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

    vertices[0][0] = destRect.origin.x;
    vertices[0][1] = destRect.origin.y;
    vertices[1][0] = NSMaxX(destRect);
    vertices[1][1] = destRect.origin.y;
    vertices[2][0] = NSMaxX(destRect);
    vertices[2][1] = NSMaxY(destRect);
    vertices[3][0] = destRect.origin.x;
    vertices[3][1] = NSMaxY(destRect);
    
    GLenum textureTarget = CVOpenGLTextureGetTarget(frame);
    // textureTarget = GL_TEXTURE_RECTANGLE_ARB;

    glEnable(textureTarget);
    glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    // Get the current texture's coordinates, bind the texture, and draw our rectangle
    CVOpenGLTextureGetCleanTexCoords(frame, texCoords[0], texCoords[1], texCoords[2], texCoords[3]);
    glBindTexture(textureTarget, CVOpenGLTextureGetName(frame));
    glDrawArrays(GL_QUADS, 0, 4);
    glDisable(textureTarget);
}

- (void) updateVideo;
{
    NSSize renderSize;
    if ([self fullScreen])
    {
        renderSize = [self centerNSSize: mFullScreenSize
                             withinRect: [self activeBounds]].size;
    }
    else
    {
        renderSize = [self stretchNSSize: mNaturalSize
                              withinRect: [self activeBounds]].size;
    }

    if (mRenderInCoreVideoThread)
    {
        render_target_set_bounds(mTarget, renderSize.width, renderSize.height,
                                 mPixelAspectRatio);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        @synchronized(self)
        {
            mRenderSize = renderSize;
            mPrimitives = primitives;
        }
    }
    else
    {
        [self lockOpenGLLock];
        
        render_target_set_bounds(mTarget, renderSize.width, renderSize.height,
                                 mPixelAspectRatio);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        [mRenderer renderFrame: primitives
                      withSize: renderSize];
        mRenderSize = renderSize;
        
        [self unlockOpenGLLock];
    }
    
    if (!mame_is_paused(mMachine))
        mFramesRendered++;
}

- (void) updatePixelAspectRatio;
{
    mPixelAspectRatio = 0.0;
    if (mKeepAspectRatio)
    {
        mPixelAspectRatio = [self aspectRatioForDisplay: kCGDirectMainDisplay];
    }
}

#define NSSTR(_cString_) [NSString stringWithCString: _cString_]

// See: 
// http://developer.apple.com/qa/qa2001/qa1217.html
- (float) aspectRatioForDisplay: (CGDirectDisplayID) displayId;
{
    NSDictionary * displayMode = (NSDictionary *) CGDisplayCurrentMode(displayId);
    // Assume square pixels, if we can't determine it.
    float aspectRatio = 1.0;
    
    //    Grab a connection to IOKit for the requested display
    io_connect_t displayPort = CGDisplayIOServicePort(displayId);
    if (displayPort != MACH_PORT_NULL)
    {
        //    Find out what IOKit knows about this display
        NSDictionary * displayDict = (NSDictionary *)
            IOCreateDisplayInfoDictionary(displayPort, 0);
        if (displayDict != nil)
        {
            NXLogDebug(@"displayDict: %@", displayDict);
            // These sizes are in millimeters (mm)
            float horizontalSize =
                [[displayDict objectForKey: NSSTR(kDisplayHorizontalImageSize)]
                    floatValue];
            float verticalSize =
                [[displayDict objectForKey: NSSTR(kDisplayVerticalImageSize)]
                    floatValue];
            //    Make sure to release the dictionary we got from IOKit
            [displayDict release];
            
            float displayWidth =
                [[displayMode objectForKey: (NSString *) kCGDisplayWidth]
                    floatValue];
            float displayHeight =
                [[displayMode objectForKey: (NSString *)  kCGDisplayHeight]
                    floatValue];
            
            float horizontalPixelsPerMM = displayWidth/horizontalSize;
            float verticalPixlesPerMM = displayHeight/verticalSize;
            aspectRatio = horizontalPixelsPerMM/verticalPixlesPerMM;
        }
    }
    return aspectRatio;
}

@end

