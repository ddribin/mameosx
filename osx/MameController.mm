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
#import "MameTimingController.h"
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
}

@interface MameController (Private)

- (void) setUpDefaultPaths;
- (NSString *) getGameNameToRun;
- (int) getGameIndex: (NSString *) gameName;
- (void) initCoreVideoBuffer;
- (void) initFilters;
- (void) pumpEvents;
- (void) updateVideo;
- (void) renderFrame;
- (void) renderLine: (render_primitive *) primitive;
- (void) renderQuad: (render_primitive *) primitive;
- (void) renderTexturedQuad: (render_primitive *) primitive
                    texture: (MameOpenGLTexture *) texture;
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
    mTimingController = [[MameTimingController alloc] initWithController: self];
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
    [mTimingController updateThrottle: emutime];
    [self updateVideo];
    [self pumpEvents];
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
    mFrameEndTime = [mTimingController osd_cycles];
}

- (void) updateVideo;
{
    [mLock lock];
    [mGlContext makeCurrentContext];

    CVOpenGLTextureRelease(mCurrentFrameTexture);
    mCurrentFrameTexture = NULL;
    CVOpenGLTextureCacheFlush(mFrameTextureCache, 0);

    // Use the buffer as the OpenGL context destination
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
    // clear the screen and Z-buffer
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

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
    mCenteringOffset = NSMakeSize(0.0f, 0.0f);

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
                [self renderLine: prim];
                break;
                
            case RENDER_PRIMITIVE_QUAD:
                MameOpenGLTexture * texture = [mTextureTable findTextureForPrimitive: prim];
                if (texture == nil)
                    [self renderQuad: prim];
                else
                    [self renderTexturedQuad: prim texture: texture];
                break;
        }
    }
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

- (void) renderLine: (render_primitive *) prim;
{
    set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
    
    // check if it's really a point
    if (((prim->bounds.x1 - prim->bounds.x0) == 0) &&
        ((prim->bounds.y1 - prim->bounds.y0) == 0))
    {
        glBegin(GL_POINTS);
        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
        glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
                   prim->bounds.y0 + mCenteringOffset.height);
        glEnd();
    }
    else
    {
        glBegin(GL_LINES);
        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
        glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
                   prim->bounds.y0 + mCenteringOffset.height);
        glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
                   prim->bounds.y1 + mCenteringOffset.height);
        glEnd();
    }
}

- (void) renderQuad: (render_primitive *) prim;
{
    set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
    glBegin(GL_QUADS);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g,
              prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glEnd();
}

- (void) renderTexturedQuad: (render_primitive *) prim 
                    texture: (MameOpenGLTexture *) texture;
{
    float du = texture->ustop - texture->ustart; 
    float dv = texture->vstop - texture->vstart;
    
    set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
    
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
    du *= (float) texture->rawwidth;
    dv *= (float) texture->rawheight;
    
    glBegin(GL_QUADS);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.tl.u,
                 texture->vstart + dv * prim->texcoords.tl.v);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.tr.u,
                 texture->vstart + dv * prim->texcoords.tr.v);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.br.u,
                 texture->vstart + dv * prim->texcoords.br.v);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.bl.u,
                 texture->vstart + dv * prim->texcoords.bl.v);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glEnd();
    glDisable(textureTarget);
}

@end
