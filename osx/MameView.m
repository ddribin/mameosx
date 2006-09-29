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

@interface MameView (Private)

- (void) detectAcceleratedCoreImage;
- (void) initDisplayLink;

- (void) gameThread;
- (void) gameFinished;

- (void) drawFrame;
- (void) drawFrameUsingCoreImage: (CVOpenGLTextureRef) frame;
- (void) drawFrameUsingOpenGL: (CVOpenGLTextureRef) frame;
- (void) updateVideo;

@end

@implementation MameView

- (id) initWithCoder: (NSCoder *) coder
{
    if ((self = [super initWithCoder: coder]) == nil)
        return nil;
    
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
    
    return self;
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

- (int) osd_init;
{
    NSLog(@"osd_init");
    
    [mInputController osd_init];
    [mAudioController osd_init];
    [mTimingController osd_init];
    
    mTarget = render_target_alloc(NULL, FALSE);
    
    render_target_set_orientation(mTarget, ROT0);
    render_target_set_layer_config(mTarget, LAYER_CONFIG_DEFAULT);
    render_target_set_view(mTarget, 0);
    render_target_get_minimum_size(mTarget, &mWindowWidth, &mWindowHeight);
    mWindowWidth *= 2;
    mWindowHeight *= 2;
    NSLog(@"%dx%d\n", mWindowWidth, mWindowHeight);
    
    NSWindow * window = [self window];
    NSSize windowSize = [[window contentView] frame].size;
    NSSize viewSize = [self frame].size;
    NSLog(@"Window size: %@, view size: %@", NSStringFromSize(windowSize), NSStringFromSize(viewSize));
    float diffX = windowSize.width - viewSize.width;
    float diffY = windowSize.height - viewSize.height;
    [window setContentSize: NSMakeSize(mWindowWidth + diffX, mWindowHeight+diffY)];
    [window center];
    [window makeKeyAndOrderFront: nil];
    
    [self createCIContext];
    [self detectAcceleratedCoreImage];
    
    NSLog(@"Use Core Image: %@", mCoreImageAccelerated? @"YES" : @"NO");
    NSLog(@"Render in Core Video thread: %@",
          mRenderInCoreVideoThread? @"YES" : @"NO");
    
    [mRenderer osd_init: [self openGLContext]
                 format: [self pixelFormat]
                  width: mWindowWidth
                 height: mWindowHeight];
    
    [self initDisplayLink];
    
    return 0;
}

- (int) osd_update: (mame_time) emutime;
{
    // Drain the pool
    [mMamePool release];
    mMamePool = [[NSAutoreleasePool alloc] init];
    
    [self updateVideo];
    // [self pumpEvents];
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

//  adjust the viewport
- (void)reshape
{ 
	GLfloat minX, minY, maxX, maxY;
    
    NSRect sceneBounds = [self bounds];
 	NSRect frame = [self frame];
	
    minX = NSMinX(sceneBounds);
	minY = NSMinY(sceneBounds);
	maxX = NSMaxX(sceneBounds);
	maxY = NSMaxY(sceneBounds);
    
    // for best results when using Core Image to render into an OpenGL context follow these guidelines:
    // * ensure that the a single unit in the coordinate space of the OpenGL context represents a single pixel in the output device
    // * the Core Image coordinate space has the origin in the bottom left corner of the screen -- you should configure the OpenGL
    //   context in the same way
    // * the OpenGL context blending state is respected by Core Image -- if the image you want to render contains translucent pixels,
    //   itÕs best to enable blending using a blend function with the parameters GL_ONE, GL_ONE_MINUS_SRC_ALPHA
    
    // some typical initialization code for a view with width W and height H
    
    glViewport(0, 0, (GLsizei)frame.size.width, (GLsizei)(frame.size.height));	// set the viewport
    
    glMatrixMode(GL_MODELVIEW);    // select the modelview matrix
    glLoadIdentity();              // reset it

    glMatrixMode(GL_PROJECTION);   // select the projection matrix
    glLoadIdentity();              // reset it
    
#if 1
    gluOrtho2D(minX, maxX, minY, maxY);	// define a 2-D orthographic projection matrix
#endif
    
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
}



#if 0
- (void) reshape
{
	NSOpenGLContext *currentContext = nil;
	NSRect bounds = NSZeroRect;
	
	currentContext = [self openGLContext];
	bounds = [self bounds];

	// [self Lock];
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
	// [self Unlock];
	
	[self setNeedsDisplay:YES];
}
#endif

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
    mame_schedule_exit(Machine);
    [mMameLock unlock];
}

- (void) togglePause;
{
    [mMameLock lock];
    if (mame_is_paused(Machine))
        mame_pause(Machine, FALSE);
    else
        mame_pause(Machine, TRUE);
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

@end

@implementation MameView (Private)

- (void) detectAcceleratedCoreImage;
{
    
    // This code fragment is from the VideoViewer sample code
    [[self openGLContext] makeCurrentContext];
    // CoreImage might be too slow if the current renderer doesn't support GL_ARB_fragment_program
    const char * glExtensions = (const char*)glGetString(GL_EXTENSIONS);
    mCoreImageAccelerated = (strstr(glExtensions, "GL_ARB_fragment_program") != NULL);
}

CVReturn myCVDisplayLinkOutputCallback(CVDisplayLinkRef displayLink, 
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
    mDisplayLock = [[NSRecursiveLock alloc] init];
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

- (void) drawFrame;
{
    [mDisplayLock lock];
    
    
    if (mRenderInCoreVideoThread)
    {
        const render_primitive_list * primitives = 0;
        BOOL skipFrame = NO;
        @synchronized(self)
        {
            primitives = mPrimitives;
            mPrimitives = 0;
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
                [mRenderer renderFrame: primitives];
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
    
    [[self openGLContext] makeCurrentContext];
    
    if (mRenderInCoreVideoThread)
        glClearColor(0.0, 0.0, 0.0, 0.0);
    else
        glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CVOpenGLTextureRef frame = [mRenderer currentFrameTexture];
    if (mCoreImageAccelerated)
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
    CGRect      imageRect;
    imageRect = [inputImage extent];
    
    CIImage * imageToDraw = inputImage;
    if (mCurrentFilter != nil)
    {
        if (mMoveInputCenter)
        {
            inputCenterX += 2;
            if (inputCenterX > mWindowWidth)
                inputCenterX = 0;
            
            [mCurrentFilter setValue: [CIVector vectorWithX: inputCenterX Y: inputCenterY]  
                              forKey: @"inputCenter"];
        }
        
        [mCurrentFilter setValue: inputImage forKey:@"inputImage"];
        imageToDraw = [mCurrentFilter valueForKey: @"outputImage"];
    }
    
    [ciContext drawImage: imageToDraw
                 atPoint: CGPointMake(0, 0)
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
    
    // Specify video rectangle vertices counter-clockwise from (0,0)
    memset(vertices, 0, sizeof(vertices));
    vertices[1][0] = vertices[2][0] = mWindowWidth;
    vertices[2][1] = vertices[3][1] = mWindowHeight;
    
    GLenum textureTarget = CVOpenGLTextureGetTarget(frame);
    
    // Make sure the correct texture target is enabled
    if (textureTarget != mLastTextureTarget)
    {
        glDisable(mLastTextureTarget);
        mLastTextureTarget = textureTarget;
        glEnable(mLastTextureTarget);
    }
    
    // Get the current texture's coordinates, bind the texture, and draw our rectangle
    CVOpenGLTextureGetCleanTexCoords(frame, texCoords[0], texCoords[1], texCoords[2], texCoords[3]);
    glBindTexture(mLastTextureTarget, CVOpenGLTextureGetName(frame));
    glDrawArrays(GL_QUADS, 0, 4);
}

- (void) updateVideo;
{
    if (mRenderInCoreVideoThread)
    {
        render_target_set_bounds(mTarget, mWindowWidth, mWindowHeight, 0.0);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        @synchronized(self)
        {
            mPrimitives = primitives;
        }
    }
    else
    {
        [mDisplayLock lock];
        
        render_target_set_bounds(mTarget, mWindowWidth, mWindowHeight, 0.0);
        const render_primitive_list * primlist = render_target_get_primitives(mTarget);
        [mRenderer renderFrame: primlist];
        
        [mDisplayLock unlock];
    }
    
    if (!mame_is_paused(Machine))
        mFramesRendered++;
}

@end

