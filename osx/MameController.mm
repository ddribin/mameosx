//
//  MameController.m
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import "MameController.h"
#import "MameView.h"
#import "MameRenderer.h"
#import "MameInputController.h"
#import "MameAudioController.h"
#import "MameTimingController.h"
#import "MameFileManager.h"
#import "MameConfiguration.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import "MameOpenGLTexture.h"
#import "MameTextureConverter.h"

#include <mach/mach_time.h>
#include <unistd.h>
#include "osd_osx.h"



// MAME headers
extern "C" {
#include "driver.h"
#include "config.h"
#include "render.h"
#include "options.h"
}

@interface MameController (Private)

- (void) setUpDefaultPaths;
- (NSString *) getGameNameToRun;
- (int) getGameIndex: (NSString *) gameName;
- (void) detectAcceleratedCoreImage;
- (void) initCoreVideoBuffer;
- (void) initFilters;
- (void) pumpEvents;
- (void) drawFrame;
- (void) drawFrameUsingCoreImage;
- (void) drawFrameUsingOpenGL;
- (void) updateVideo;

@end

void leaks_sleeper()
{
    while (1) sleep(60);
}

@implementation MameController

- (id) init
{
    if (![super init])
        return nil;
   
    mRenderer = [[MameRenderer alloc] init];
    mInputController = [[MameInputController alloc] init];
    mAudioController = [[MameAudioController alloc] initWithController: self];
    mTimingController = [[MameTimingController alloc] initWithController: self];
    mFileManager = [[MameFileManager alloc] init];
    mConfiguration = [[MameConfiguration alloc] initWithController: self];
    mSyncToRefresh = NO;

    return self;
}

- (void) applicationDidFinishLaunching: (NSNotification*) notification;
{
    NSLog(@"didFinishLaunching");

#if 0
    atexit(leaks_sleeper);
#endif
    osd_set_controller(self);
    osd_set_input_controller(mInputController);
    osd_set_audio_controller(mAudioController);
    osd_set_timing_controller(mTimingController);
    osd_set_file_manager(mFileManager);
    
    [mDrawer setContentSize: NSMakeSize(20, 60)];
    mIsFiltered = NO;
    int res = 0;
    
    if (NSClassFromString(@"SenTestCase") != nil)
        return;
    
    [self setUpDefaultPaths];
    [mConfiguration loadUserDefaults];
    [self setThrottled: [mConfiguration throttled]];
    [self setSyncToRefresh: [mConfiguration syncToRefresh]];

    NSString * gameName = [self getGameNameToRun];
    NSLog(@"Running %@", gameName);
    int game_index = [self getGameIndex: gameName];
    
    // have we decided on a game?
    if (game_index != -1)
        res = run_game(game_index);
    
    cycles_t cps = [mTimingController osd_cycles_per_second];
    NSLog(@"Average FPS displayed: %f (%qi frames)\n",
           (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesDisplayed,
           mFramesDisplayed);
    NSLog(@"Average FPS rendered: %f (%qi frames)\n",
           (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesRendered,
           mFramesRendered);
    
    exit(res);
}

- (int) osd_init;
{
    NSLog(@"osd_init");

    [mGameLoading stopAnimation: nil];
    [mOpenPanel orderOut: [mMameView window]];

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
    
    NSWindow * window = [mMameView window];
    NSSize windowSize = [[window contentView] frame].size;
    NSSize viewSize = [mMameView frame].size;
    NSLog(@"Window size: %@, view size: %@", NSStringFromSize(windowSize), NSStringFromSize(viewSize));
    float diffX = windowSize.width - viewSize.width;
    float diffY = windowSize.height - viewSize.height;
    [window setContentSize: NSMakeSize(mWindowWidth + diffX, mWindowHeight+diffY)];
    [window center];
    [window makeKeyAndOrderFront: nil];
    
    [mMameView createCIContext];
    [self detectAcceleratedCoreImage];
    
    [mRenderer osd_init: [mMameView openGLContext]
                 format: [mMameView pixelFormat]
                  width: mWindowWidth
                 height: mWindowHeight];
    
    [self initCoreVideoBuffer];
    
    return 0;
}

- (MameConfiguration *) configuration;
{
    return mConfiguration;
}

- (MameFileManager *) fileManager;
{
    return mFileManager;
}

- (int) osd_update: (mame_time) emutime;
{
    [self updateVideo];
    [self pumpEvents];
    [mTimingController updateThrottle: emutime];
    return 0;
}

//=========================================================== 
//  isFiltered 
//=========================================================== 
- (BOOL) isFiltered
{
    return mIsFiltered;
}

- (void) setIsFiltered: (BOOL) flag
{
    mIsFiltered = flag;
}

- (IBAction) filterChanged: (id) sender;
{
    unsigned index = [mFilterButton indexOfSelectedItem];
    if (index >= [mFilters count])
        return;
    
    mCurrentFilter = [mFilters objectAtIndex: index];
    if (index == 2)
        mMoveInputCenter = YES;
    else
        mMoveInputCenter = NO;
}

- (IBAction) togglePause: (id) sender;
{
    if (mame_is_paused())
        mame_pause(FALSE);
    else
        mame_pause(TRUE);
}

- (IBAction) nullAction: (id) sender;
{
}

- (IBAction) raiseOpenPanel: (id) sender;
{
    [NSApp runModalForWindow: mOpenPanel];
    [mGameLoading startAnimation: nil];
}

- (IBAction) endOpenPanel: (id) sender;
{
    [NSApp stopModal];
}

//=========================================================== 
//  throttled 
//=========================================================== 
- (BOOL) throttled
{
    return mThrottled;
}

- (void) setThrottled: (BOOL) flag
{
    mThrottled = flag;
}

//=========================================================== 
//  syncToRefresh 
//=========================================================== 
- (BOOL) syncToRefresh
{
    return mSyncToRefresh;
}

- (void) setSyncToRefresh: (BOOL) flag
{
    mSyncToRefresh = flag;
    long swapInterval;
    if (mSyncToRefresh)
        swapInterval = 1;
    else
        swapInterval = 0;
    
    [mLock lock];
    [[mMameView openGLContext] setValues: &swapInterval
                            forParameter: NSOpenGLCPSwapInterval];
    [mLock unlock];
}


@end

@implementation MameController (Private)

- (void) setUpDefaultPaths;
{
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    [mFileManager setPath: [myBundle resourcePath] forType: FILETYPE_FONT];
}

- (NSString *) getGameNameToRun;
{
    NSArray * arguments = [[NSProcessInfo processInfo] arguments];
    NSString * lastArgument = [arguments lastObject];
    if (([arguments count] > 1) && ![lastArgument hasPrefix: @"-"])
    {
        return lastArgument;
    }
    else
    {
        [self raiseOpenPanel: nil];
        return [mGameTextField stringValue];
    }
}

- (int) getGameIndex: (NSString *) gameName;
{
    if (gameName == nil)
        return -1;
    return driver_get_index([gameName UTF8String]);
}

CVReturn myCVDisplayLinkOutputCallback(CVDisplayLinkRef displayLink, 
                                       const CVTimeStamp *inNow, 
                                       const CVTimeStamp *inOutputTime, 
                                       CVOptionFlags flagsIn, 
                                       CVOptionFlags *flagsOut, 
                                       void *displayLinkContext)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    MameController * controller = (MameController *) displayLinkContext;
    [controller drawFrame];
    [pool release];
    return kCVReturnSuccess;
}

static void cv_assert(CVReturn cr, NSString * message)
{
    if (cr != kCVReturnSuccess)
        NSLog(@"Core video returned: %d: %@", cr, message);
}

- (void) detectAcceleratedCoreImage;
{
    
    // This code fragment is from the VideoViewer sample code
    [[mMameView openGLContext] makeCurrentContext];
    // CoreImage might be too slow if the current renderer doesn't support GL_ARB_fragment_program
    const char * glExtensions = (const char*)glGetString(GL_EXTENSIONS);
    mCoreImageAccelerated = (strstr(glExtensions, "GL_ARB_fragment_program") != NULL);
    NSLog(@"Use Core Image: %@", mCoreImageAccelerated? @"YES" : @"NO");
}

- (void) initCoreVideoBuffer;
{
    mLock = [[NSRecursiveLock alloc] init];
    
    [self initFilters];

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

- (void) initFilters;
{
    mFilters = [[NSMutableArray alloc] init];
    mMoveInputCenter = NO;
    inputCenterX = mWindowWidth/2;
    inputCenterY = mWindowHeight/2;
    
    CIFilter * filter;
    
    filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 3]  
              forKey: @"inputRadius"];
    [mFilters addObject: filter];
    
    filter = [CIFilter filterWithName:@"CIZoomBlur"];
    [filter setDefaults];
    [filter setValue: [CIVector vectorWithX: inputCenterX Y: inputCenterY]
              forKey: @"inputCenter"];
    [filter setValue: [NSNumber numberWithFloat: 10]
              forKey: @"inputAmount"];
    [mFilters addObject: filter];

    filter = [CIFilter filterWithName:@"CIBumpDistortion"];
    [filter setDefaults];
    [filter setValue: [CIVector vectorWithX: inputCenterX Y: inputCenterY]
              forKey: @"inputCenter"];
    [filter setValue: [NSNumber numberWithFloat: 75]  
              forKey: @"inputRadius"];
    [filter setValue: [NSNumber numberWithFloat:  3.0]  
              forKey: @"inputScale"];
    [mFilters addObject: filter];

    filter = [CIFilter filterWithName:@"CICrystallize"];
    [filter setDefaults];
    [filter setValue: [CIVector vectorWithX: inputCenterX Y: inputCenterY]
              forKey: @"inputCenter"];
    [filter setValue: [NSNumber numberWithFloat: 3]
             forKey: @"inputRadius"];
    [mFilters addObject: filter];

    filter = [CIFilter filterWithName:@"CIPerspectiveTile"];
    [filter setDefaults];
    [mFilters addObject: filter];
    
    filter = [CIFilter filterWithName:@"CIBloom"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 1.5f]
              forKey: @"inputIntensity"];
    [mFilters addObject: filter];
    
    filter = [CIFilter filterWithName:@"CIEdges"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 5]  
              forKey: @"inputIntensity"];
    [mFilters addObject: filter];
    
    mCurrentFilter = [mFilters objectAtIndex: 0];
}

- (void) pumpEvents;
{
    while(1)
    {
        /* Poll for an event. This will not block */
        NSEvent * event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                             untilDate: nil
                                                inMode: NSDefaultRunLoopMode
                                               dequeue: YES];
        if (event == nil)
            break;
        
        if ([event type] == NSKeyDown)
            [mInputController handleKeyDown: event];
        else if ([event type] == NSKeyUp)
            [mInputController handleKeyUp: event];
        else if ([event type] == NSFlagsChanged)
            [mInputController flagsChanged: event];
        
        [NSApp sendEvent: event];
    }
}

- (void) drawFrame;
{
    [mLock lock];
    [[mMameView openGLContext] makeCurrentContext];

    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    if (mCoreImageAccelerated)
        [self drawFrameUsingCoreImage];
    else
        [self drawFrameUsingOpenGL];
    
    glFlush();
    
    [mLock unlock];

    mFramesDisplayed++;
    mFrameEndTime = [mTimingController osd_cycles];
}

- (void) drawFrameUsingCoreImage;
{
    CIImage * inputImage = [CIImage imageWithCVImageBuffer: [mRenderer currentFrameTexture]];
    CIContext * ciContext = [mMameView ciContext];
    CGRect      imageRect;
    imageRect = [inputImage extent];
    
    
    CIImage * imageToDraw = inputImage;
    if (mIsFiltered)
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

- (void) drawFrameUsingOpenGL;
{
    CVOpenGLTextureRef texture = [mRenderer currentFrameTexture];
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
    
    GLenum textureTarget = CVOpenGLTextureGetTarget(texture);
    
    // Make sure the correct texture target is enabled
    if (textureTarget != mLastTextureTarget)
    {
        glDisable(mLastTextureTarget);
        mLastTextureTarget = textureTarget;
        glEnable(mLastTextureTarget);
    }
    
    // Get the current texture's coordinates, bind the texture, and draw our rectangle
    CVOpenGLTextureGetCleanTexCoords(texture, texCoords[0], texCoords[1], texCoords[2], texCoords[3]);
    glBindTexture(mLastTextureTarget, CVOpenGLTextureGetName(texture));
    glDrawArrays(GL_QUADS, 0, 4);
}

- (void) updateVideo;
{
    [mLock lock];

    render_target_set_bounds(mTarget, mWindowWidth, mWindowHeight, 0);
    const render_primitive_list * primlist = render_target_get_primitives(mTarget);
    [mRenderer renderFrame: primlist];
    
    [mLock unlock];
    mFramesRendered++;
}

@end
