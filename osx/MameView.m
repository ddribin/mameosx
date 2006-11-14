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
#import "MameFilter.h"


@interface MameView (Private)

- (void) detectAcceleratedCoreImage;

- (void) gameThread;
- (void) gameFinished;

#pragma mark -
#pragma mark "Notifications and Delegates"

- (void) sendMameWillStartGame;
- (void) sendMameDidFinishGame;

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

@end

NSString * MameWillStartGame = @"MameWillStartGame";
NSString * MameDidFinishGame = @"MameDidFinishGame";

@implementation MameView

-(id) initWithFrame: (NSRect) frameRect
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
    
    mClearToRed = NO;
    mFrameStartTime = 0;

    return self;
}

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

- (int) osd_init: (running_machine *) machine;
{
    NSLog(@"osd_init");
    
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
    [self detectAcceleratedCoreImage];
    
    NSLog(@"Use Core Image: %@", mCoreImageAccelerated? @"YES" : @"NO");
    NSLog(@"Render in Core Video thread: %@",
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

- (int) osd_update: (mame_time) emutime;
{
    // Drain the pool
    [mMamePool release];
    mMamePool = [[NSAutoreleasePool alloc] init];
    
    [self updateVideo];
    if (mFrameStartTime == 0)
        mFrameStartTime = [mTimingController osd_cycles];
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

- (int) osd_display_loading_rom_message: (const char *) name
                                romdata: (rom_load_data *) romdata;
{
    if (name != 0)
    {
        if ([mDelegate respondsToSelector: @selector(mameRomLoadingMessage:romsLoaded:romCount:)])
        {
            [mDelegate mameRomLoadingMessage: [NSString stringWithUTF8String: name]
                                  romsLoaded: romdata->romsloaded
                                    romCount: romdata->romstotal];
        }
                                                     
    }
    else
    {
        if ([mDelegate respondsToSelector: @selector(mameRomLoadingFinishedWithErrors:errorMessage:)])
        {
            BOOL errors = (romdata->errors == 0)? NO : YES;
            NSString * errorMessage =
                [NSString stringWithUTF8String: romdata->errorbuf];
            [mDelegate mameRomLoadingFinishedWithErrors: errors
                                           errorMessage: errorMessage];
        }
    }
    return 0;
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

- (void) detectAcceleratedCoreImage;
{
    
    // This code fragment is from the VideoViewer sample code
    [[self openGLContext] makeCurrentContext];
    // CoreImage might be too slow if the current renderer doesn't support GL_ARB_fragment_program
    const GLubyte * glExtensions = glGetString(GL_EXTENSIONS);
    const GLubyte * extension = (const GLubyte *)"GL_ARB_fragment_program";
    mCoreImageAccelerated = gluCheckExtension(extension, glExtensions);
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
    [[NSNotificationCenter defaultCenter] postNotificationName: MameDidFinishGame
                                                        object: self];
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
#if 0
        NSLog(@"currentBounds: %@, renderSize: %@, destRect: %@",
              NSStringFromRect(currentBounds),
              NSStringFromSize(mRenderSize),
              NSStringFromRect(destRect));
#endif
    }
    else
        destRect = [self stretchNSSize: mRenderSize withinRect: currentBounds];

    if (YES) // (mCoreImageAccelerated)
        [self drawFrameUsingCoreImage: frame inRect: destRect];
    else
        [self drawFrameUsingOpenGL: frame inRect: destRect];
    
    mFramesDisplayed++;
    mFrameEndTime = [mTimingController osd_cycles];
}

- (void) drawFrameUsingCoreImage: (CVOpenGLTextureRef) frame
                          inRect: (NSRect) destRect;
{
    CIImage * frameIamge = [CIImage imageWithCVImageBuffer: frame];
    CIContext * ciContext = [self ciContext];

    if (mFilter != nil)
    {
        frameIamge = [mFilter filterFrame: frameIamge size: destRect.size];
    }
    CGRect imageRect = [frameIamge extent];
    
    [ciContext drawImage: frameIamge
                  inRect: *(CGRect *) &destRect
                fromRect: imageRect];
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
        [self lockOpenGLLock];
        
        render_target_set_bounds(mTarget, renderSize.width, renderSize.height, 0.0);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        [mRenderer renderFrame: primitives
                      withSize: renderSize];
        mRenderSize = renderSize;
        
        [self unlockOpenGLLock];
    }
    
    if (!mame_is_paused(mMachine))
        mFramesRendered++;
}

@end

