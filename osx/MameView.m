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

NSString * MameViewNaturalSizeDidChange = @"NaturalSizeDidChange";

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

- (NSSize) naturalSize;
{
    return mNaturalSize;
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
	NSOpenGLContext *currentContext = nil;
	NSRect bounds = NSZeroRect;
	
	currentContext = [self openGLContext];
	bounds = [self bounds];
    
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
                              withSize: NSIntegralRect([self bounds]).size];
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
        glClearColor(1.0, 0.0, 0.0, 0.0);
    else
        glClearColor(1.0, 0.0, 0.0, 0.0);
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
    NSSize size = [self bounds].size;
    memset(vertices, 0, sizeof(vertices));
    vertices[1][0] = vertices[2][0] = size.width;
    vertices[2][1] = vertices[3][1] = size.height;
    
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
    NSSize windowSize = NSIntegralRect([self bounds]).size;
    if (mRenderInCoreVideoThread)
    {
        render_target_set_bounds(mTarget, windowSize.width, windowSize.height, 0.0);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        @synchronized(self)
        {
            mPrimitives = primitives;
        }
    }
    else
    {
        [mDisplayLock lock];
        
        render_target_set_bounds(mTarget, windowSize.width, windowSize.height, 0.0);
        const render_primitive_list * primitives = render_target_get_primitives(mTarget);
        [mRenderer renderFrame: primitives
                      withSize: windowSize];
        
        [mDisplayLock unlock];
    }
    
    if (!mame_is_paused(mMachine))
        mFramesRendered++;
}

@end

