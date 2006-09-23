//
//  MameController.m
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import "MameController.h"
#import "MameView.h"
#import "MameInputController.h"
#import "MameAudioController.h"
#import "MameFileManager.h"
#import "MameConfiguration.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import "MameTextureTable.h"
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

extern int *_NSGetArgc(void);
extern char ***_NSGetArgv(void);
}

@interface MameController (Private)

enum
{
    TEXTURE_TYPE_PLAIN,
    TEXTURE_TYPE_DYNAMIC,
    TEXTURE_TYPE_SURFACE
};

- (void) setUpDefaultPaths;
- (NSString *) getGameNameToRun;
- (int) getGameIndex: (NSString *) gameName;
- (void) initTimer;
- (void) initCoreVideoBuffer;
- (void) initFilters;
- (void) pumpEvents;
- (void) updateThrottle: (mame_time) emutime;
- (void) updateVideo;
- (void) renderFrame;
- (void) drawFrame;

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
   
    mInputController = [[MameInputController alloc] init];
    mAudioController = [[MameAudioController alloc] initWithController: self];
    mFileManager = [[MameFileManager alloc] init];
    mConfiguration = [[MameConfiguration alloc] initWithController: self];
    mTextureTable = [[MameTextureTable alloc] init];
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

    NSLog(@"Running");
    NSString * gameName = [self getGameNameToRun];
    int game_index = [self getGameIndex: gameName];
    
    // have we decided on a game?
    if (game_index != -1)
        res = run_game(game_index);
    
    cycles_t cps = [self osd_cycles_per_second];
    printf("Average FPS displayed: %f (%qi frames)\n",
           (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesDisplayed,
           mFramesDisplayed);
    printf("Average FPS rendered: %f (%qi frames)\n",
           (double)cps / (mFrameEndTime - mFrameStartTime) * mFramesRendered,
           mFramesRendered);
    
    exit(res);
}

- (int) osd_init;
{
    NSLog(@"osd_init");

    [self initTimer];
    [mInputController osd_init];
    [mAudioController osd_init];
    mThrottleLastCycles = 0;   
    
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
    [self updateThrottle: emutime];
    [self updateVideo];
    [self pumpEvents];
    return 0;
}

- (cycles_t) osd_cycles;
{
    return mach_absolute_time();
}

- (cycles_t) osd_cycles_per_second;
{
    return mCyclesPerSecond;
}

- (cycles_t) osd_profiling_ticks;
{
    return mach_absolute_time();
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
    if ([arguments count] > 1)
    {
        return [arguments lastObject];
    }
    return nil;
}

- (int) getGameIndex: (NSString *) gameName;
{
    if (gameName == nil)
        return -1;
    return driver_get_index([gameName UTF8String]);
}

- (void) initTimer;
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    mCyclesPerSecond = 1000000000LL *
        ((uint64_t)info.denom) / ((uint64_t)info.numer);
    NSLog(@"cycles/second = %u/%u = %lld\n", info.denom, info.numer,
          mCyclesPerSecond);
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

- (void) initCoreVideoBuffer;
{
    mLock = [[NSRecursiveLock alloc] init];

    //Create the OpenGL context used to render the composition (a separate OpenGL context from the destination one is needed to render into CoreVideo OpenGL buffers)
    NSOpenGLPixelFormat * glPixelFormat = [mMameView pixelFormat];
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
    if(CVOpenGLBufferPoolCreate(NULL, NULL, (CFDictionaryRef)bufferOptions, &mBufferPool) != kCVReturnSuccess)
    {
        NSLog(@"Could not create buffer pool");
        mBufferPool = NULL;
    }
    if (CVOpenGLBufferCreate(NULL, mWindowWidth, mWindowHeight, (CFDictionaryRef)bufferOptions,
                             &mCurrentFrame))
    {
        NSLog(@"Could not create current frame buffer");
    }
    
    NSOpenGLContext * cacheContext = [mMameView openGLContext];
    NSOpenGLPixelFormat * cachePFormat = [mMameView pixelFormat];
    cv_assert(CVOpenGLTextureCacheCreate(NULL, 0, (CGLContextObj) [cacheContext CGLContextObj],
                                         (CGLPixelFormatObj) [cachePFormat CGLPixelFormatObj], 0, &mFrameTextureCache),
              @"Could not create frame texture cache");
    
    cv_assert(CVOpenGLTextureCacheCreate(NULL, 0, (CGLContextObj) [mGlContext CGLContextObj],
                               (CGLPixelFormatObj) [glPixelFormat CGLPixelFormatObj], 0, &mPrimTextureCache),
              @"Could not create primitive texture cache");

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
    mFrameStartTime = [self osd_cycles];
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

// refresh rate while paused
#define PAUSED_REFRESH_RATE         30

- (void) updateThrottle: (mame_time) emutime;
{
#if 0
    NSLog(@"emutime: %i, %qi", emutime.seconds, emutime.subseconds);
#endif
    int paused = mame_is_paused();
    if (paused)
    {
#if 0        
        mThrottleRealtime = mThrottleEmutime = sub_subseconds_from_mame_time(emutime, MAX_SUBSECONDS / PAUSED_REFRESH_RATE);
#else
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
#endif
    }
   
    // if time moved backwards (reset), or if it's been more than 1 second in emulated time, resync
    if (compare_mame_times(emutime, mThrottleEmutime) < 0 || sub_mame_times(emutime, mThrottleEmutime).seconds > 0)
    {
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
    }

    cycles_t cyclesPerSecond = [self osd_cycles_per_second];
    cycles_t diffCycles = [self osd_cycles] - mThrottleLastCycles;
    mThrottleLastCycles += diffCycles;
    // NSLog(@"diff: %llu, last: %llu", diffCycles, mThrottleLastCycles);
    if (diffCycles > cyclesPerSecond)
    {
        NSLog(@"More than 1 sec, diff: %qi, cps: %qi", diffCycles, cyclesPerSecond);
        // Resync
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
    }
    
    subseconds_t subsecsPerCycle = MAX_SUBSECONDS / cyclesPerSecond;
#if 1
    // NSLog(@"max: %qi, sspc: %qi, add_subsecs: %qi, diff: %qi", MAX_SUBSECONDS, subsecsPerCycle, diffCycles * subsecsPerCycle, diffCycles);
    // NSLog(@"realtime: %i, %qi", mThrottleRealtime.seconds, mThrottleRealtime.subseconds);
#endif
    mThrottleRealtime = add_subseconds_to_mame_time(mThrottleRealtime, diffCycles * subsecsPerCycle);
    mThrottleEmutime = emutime;

    // if we're behind, just sync
    if (compare_mame_times(mThrottleEmutime, mThrottleRealtime) <= 0)
    {
        mThrottleRealtime = mThrottleEmutime = emutime;
        return;
    }
    
    mame_time timeTilTarget = sub_mame_times(mThrottleEmutime, mThrottleRealtime);
    cycles_t target = mThrottleLastCycles + timeTilTarget.subseconds / subsecsPerCycle;
    
    cycles_t curr = [self osd_cycles];
    uint64_t count = 0;
#if 1
    if (mThrottled)
    {
        for (curr = [self osd_cycles]; curr - target < 0; curr = [self osd_cycles])
        {
            // NSLog(@"target: %qi, current %qi, diff: %qi", target, curr, curr - target);
            // Spin...
            count++;
        }
    }
#endif
    
    // update realtime
    diffCycles = [self osd_cycles] - mThrottleLastCycles;
    mThrottleLastCycles += diffCycles;
    mThrottleRealtime = add_subseconds_to_mame_time(mThrottleRealtime, diffCycles * subsecsPerCycle);
    
    return;
}

INLINE void set_blendmode(int blendmode)
{
        switch (blendmode)
        {
            case BLENDMODE_NONE:
                glDisable(GL_BLEND);
                break;
            case BLENDMODE_ALPHA:       
                glEnable(GL_BLEND);
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                break;
            case BLENDMODE_RGB_MULTIPLY:    
                glEnable(GL_BLEND);
                glBlendFunc(GL_DST_COLOR, GL_ZERO);
                break;
            case BLENDMODE_ADD:     
                glEnable(GL_BLEND);
                glBlendFunc(GL_SRC_ALPHA, GL_ONE);
                break;
        }
}

- (void) drawFrame;
{
    [mLock lock];
    [[mMameView openGLContext] makeCurrentContext];

    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    CIImage * inputImage = [CIImage imageWithCVImageBuffer: mCurrentFrameTexture];
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
   
#if 1
    [ciContext drawImage: imageToDraw
                 atPoint: CGPointMake(0, 0)
                fromRect: imageRect];
#endif
    
    glFlush();
    
    [mLock unlock];

    mFramesDisplayed++;
    mFrameEndTime = [self osd_cycles];
}

- (void) updateVideo;
{
    [mLock lock];
    [mGlContext makeCurrentContext];

    CVOpenGLTextureRelease(mCurrentFrameTexture);
    mCurrentFrameTexture = NULL;
    CVOpenGLTextureCacheFlush(mFrameTextureCache, 0);

    //Use the buffer as the OpenGL context destination
    if(CVOpenGLBufferAttach(mCurrentFrame, (CGLContextObj) [mGlContext CGLContextObj], 0, 0, 0) == kCVReturnSuccess)
    {
        [self renderFrame];
        glFlush();
        CVOpenGLTextureCacheCreateTextureFromImage(NULL, mFrameTextureCache,
                                                   mCurrentFrame,
                                                   0, &mCurrentFrameTexture);
    }

    [mLock unlock];
    mFramesRendered++;
}

- (void) renderFrame;
{
    float du, dv, vofs, hofs;

   
    // clear the screen and Z-buffer
    glClear(GL_COLOR_BUFFER_BIT); // | GL_DEPTH_BUFFER_BIT);
                                  // reset the current matrix to the identity
    glLoadIdentity();                                  
    
    // we're doing nothing 3d, so the Z-buffer is currently not interesting
    glDisable(GL_DEPTH_TEST);
    
    glDisable(GL_LINE_SMOOTH);
    glDisable(GL_POINT_SMOOTH);
    
    // enable blending
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    // set lines and points just barely above normal size to get proper results
    glLineWidth(1.1f);
    glPointSize(1.1f);
    
    // set up a nice simple 2D coordinate system, so GL behaves exactly how we'd like.
    //
    // (0,0)     (w,0)
    //   |~~~~~~~~~|
    //   |         |
    //   |         |
    //   |         |
    //   |_________|
    // (0,h)     (w,h)
    
    glViewport(0.0, 0.0, (GLsizei)mWindowWidth, (GLsizei)mWindowHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, (GLdouble)mWindowWidth, (GLdouble)mWindowHeight, 0.0, 0.0, -1.0);
    
    // compute centering parameters
    vofs = hofs = 0.0f;

    render_target_set_bounds(mTarget, mWindowWidth, mWindowHeight, 0);
    const render_primitive_list * primlist = render_target_get_primitives(mTarget);

    // first update/upload the textures
    CVOpenGLTextureCacheFlush(mPrimTextureCache, 0);
    
    render_primitive * prim;
    for (prim = primlist->head; prim != NULL; prim = prim->next)
    {
        if (prim->texture.base != NULL)
        {
            [mTextureTable update: prim textureCache: mPrimTextureCache];
        }
    }
    
    // now draw
    for (prim = primlist->head; prim != NULL; prim = prim->next)
    {
        switch (prim->type)
        {
            case RENDER_PRIMITIVE_LINE:
                set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
                
                // check if it's really a point
                if (((prim->bounds.x1 - prim->bounds.x0) == 0) && ((prim->bounds.y1 - prim->bounds.y0) == 0))
                {
                    glBegin(GL_POINTS);
                    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                    glVertex2f(prim->bounds.x0+hofs, prim->bounds.y0+vofs);
                    glEnd();
                }
                else
                {
                    glBegin(GL_LINES);
                    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                    glVertex2f(prim->bounds.x0+hofs, prim->bounds.y0+vofs);
                    glVertex2f(prim->bounds.x1+hofs, prim->bounds.y1+vofs);
                    glEnd();
                }
                break;
                
            case RENDER_PRIMITIVE_QUAD:
                MameOpenGLTexture * texture = [mTextureTable findTextureForPrimitive: prim];

                set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
                
                // select the texture
                if (texture != nil)
                {
                    du = texture->ustop - texture->ustart; 
                    dv = texture->vstop - texture->vstart;
                    
                    //                  printf("draw: %d  alpha: %f\n", texture->texturename, prim->color.a);
                    
                    GLenum textureTarget = CVOpenGLTextureGetTarget(texture->cv_texture);
                    glEnable(textureTarget);
                    glBindTexture(CVOpenGLTextureGetTarget(texture->cv_texture),
                                  CVOpenGLTextureGetName(texture->cv_texture));
                    
                    // non-screen textures will never be filtered
                    glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                    glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
                    
                    // texture rectangles can't wrap
                    glTexParameteri(textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP);
                    glTexParameteri(textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP);
                    
                    // texture coordinates for TEXTURE_RECTANGLE are 0,0 -> w,h
                    // rather than 0,0 -> 1,1 as with normal OpenGL texturing
                    du *= (float)texture->rawwidth;
                    dv *= (float)texture->rawheight;
                    
                    glBegin(GL_QUADS);
                    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                    glTexCoord2f(texture->ustart + du * prim->texcoords.tl.u, texture->vstart + dv * prim->texcoords.tl.v);
                    glVertex2f(prim->bounds.x0 + hofs, prim->bounds.y0 + vofs);
                    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                    glTexCoord2f(texture->ustart + du * prim->texcoords.tr.u, texture->vstart + dv * prim->texcoords.tr.v);
                    glVertex2f(prim->bounds.x1 + hofs, prim->bounds.y0 + vofs);
                    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                    glTexCoord2f(texture->ustart + du * prim->texcoords.br.u, texture->vstart + dv * prim->texcoords.br.v);
                    glVertex2f(prim->bounds.x1 + hofs, prim->bounds.y1 + vofs);
                    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                    glTexCoord2f(texture->ustart + du * prim->texcoords.bl.u, texture->vstart + dv * prim->texcoords.bl.v);
                    glVertex2f(prim->bounds.x0 + hofs, prim->bounds.y1 + vofs);
                    glEnd();
                    glDisable(textureTarget);
                }
                    else    // untextured quad
                    {
                        glBegin(GL_QUADS);
                        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                        glVertex2f(prim->bounds.x0 + hofs, prim->bounds.y0 + vofs);
                        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                        glVertex2f(prim->bounds.x1 + hofs, prim->bounds.y0 + vofs);
                        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                        glVertex2f(prim->bounds.x1 + hofs, prim->bounds.y1 + vofs);
                        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
                        glVertex2f(prim->bounds.x0 + hofs, prim->bounds.y1 + vofs);
                        glEnd();
                    }
                        break;
        }
    }
}

@end
