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
#include "render.h"
}

@interface MameController (Private)

- (void) setUpDefaultPaths;
- (NSString *) getGameNameToRun;
- (void) initFilters;
- (void) pumpEvents;

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
   
    mConfiguration = [[MameConfiguration alloc] init];

    return self;
}

- (void) applicationDidFinishLaunching: (NSNotification*) notification;
{
#if 0
    atexit(leaks_sleeper);
#endif
    osd_set_controller(self);
    
    // Work around for an IB issue:
    // "Why does my bottom or top drawer size itself improperly?"
    // http://developer.apple.com/documentation/DeveloperTools/Conceptual/IBTips/Articles/FreqAskedQuests.html
    [mDrawer setContentSize: NSMakeSize(20, 60)];
    
    if (NSClassFromString(@"SenTestCase") != nil)
        return;
    
    [mConfiguration setFileManager: [mMameView fileManager]];
    [self setUpDefaultPaths];
    [mConfiguration loadUserDefaults];
    [mMameView setAudioEnabled: [mConfiguration soundEnabled]];
    [mMameView setThrottled: [mConfiguration throttled]];
    [mMameView setSyncToRefresh: [mConfiguration syncToRefresh]];
    
    [mMameView setGame: [self getGameNameToRun]];
    [mMameView start];
    [self hideOpenPanel: nil];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    NSApplicationTerminateReply reply = NSTerminateNow;
    if ([mMameView isRunning])
    {
        [mMameView stop];
        // Thread notification will actually terminate the app
        reply =  NSTerminateCancel;
    }
    return reply;
}

- (int) osd_init;
{
    [mMameView osd_init];
    return 0;
}

- (MameConfiguration *) configuration;
{
    return mConfiguration;
}

- (int) osd_update: (mame_time) emutime;
{
    [mMameView osd_update: emutime];
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
    [mMameView togglePause];
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

- (IBAction) hideOpenPanel: (id) sender;
{
    [mGameLoading stopAnimation: nil];
    [mOpenPanel orderOut: [mMameView window]];
}

//=========================================================== 
//  throttled 
//=========================================================== 
- (BOOL) throttled
{
    return [mMameView throttled];
}

- (void) setThrottled: (BOOL) flag
{
    [mMameView setThrottled: flag];
}

//=========================================================== 
//  syncToRefresh 
//=========================================================== 
- (BOOL) syncToRefresh
{
    return [mMameView syncToRefresh];
}

- (void) setSyncToRefresh: (BOOL) flag
{
    [mMameView setSyncToRefresh: flag];
}


@end

@implementation MameController (Private)

- (void) setUpDefaultPaths;
{
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    [[mMameView fileManager] setPath: [myBundle resourcePath] forType: FILETYPE_FONT];
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

- (void) initFilters;
{
    mFilters = [[NSMutableArray alloc] init];
    mMoveInputCenter = NO;
    // inputCenterX = mWindowWidth/2;
    // inputCenterY = mWindowHeight/2;
    
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
        [NSApp sendEvent: event];
    }
}

@end
