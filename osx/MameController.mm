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

NSString * kMamePreviousGames = @"PreviousGames";
NSString * kMameGame = @"Game";
NSString * kMameSleepAtExit = @"SleepAtExit";

static const int kMameRunGame = 0;
static const int kMameCancelGame = 1;

@interface MameController (Private)

- (void) setViewSize: (NSSize) viewSize;
- (void) viewNaturalSizeDidChange: (NSNotification *) notification;
- (void) setUpDefaultPaths;
- (NSString *) getGameNameToRun;
- (void) initFilters;
- (void) updatePreviousGames: (NSString *) gameName;

@end

static BOOL sSleepAtExit = NO;

void exit_sleeper()
{
    while (sSleepAtExit) sleep(60);
}

@implementation MameController

- (id) init
{
    if (![super init])
        return nil;
   
    mConfiguration = [[MameConfiguration alloc] init];
    [self initFilters];

    sSleepAtExit =
        [[NSUserDefaults standardUserDefaults] boolForKey: kMameSleepAtExit];
    atexit(exit_sleeper);
    
    return self;
}

- (void) awakeFromNib
{
    [[mMameView window] center];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(viewNaturalSizeDidChange:)
                                                 name: MameViewNaturalSizeDidChange
                                               object: mMameView];
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    [self willChangeValueForKey: @"previousGames"];
    mPreviousGames = [[defaults arrayForKey: kMamePreviousGames] mutableCopy];
    if (mPreviousGames == nil)
        mPreviousGames = [[NSMutableArray alloc] init];
    [self didChangeValueForKey: @"previousGames"];
}

- (void) applicationDidFinishLaunching: (NSNotification*) notification;
{
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
    [mMameView setRenderInCoreVideoThread: [mConfiguration renderInCV]];
    [mMameView setClearToRed: [mConfiguration clearToRed]];
    
    NSString * gameName = [self getGameNameToRun];
    if ([mMameView setGame: gameName])
    {
        [self updatePreviousGames: gameName];
        
        [mMameView start];
        [self hideOpenPanel: nil];
    }
    else
    {
        NSLog(@"Game not found: %@", gameName);
        [NSApp terminate: nil];
    }
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

- (void) applicationWillTerminate: (NSNotification *) notification;
{
    [[mMameView window] orderOut: nil];
    [mMameView setFullScreen: false];
}

- (MameConfiguration *) configuration;
{
    return mConfiguration;
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
    if (mIsFiltered)
        [mMameView setFilter: mCurrentFilter];
    else
        [mMameView setFilter: nil];
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
    if (mIsFiltered)
        [mMameView setFilter: mCurrentFilter];
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
    int rc = [NSApp runModalForWindow: mOpenPanel];
    if (rc == kMameRunGame)
    {
        [mGameLoading startAnimation: nil];
    }
    else
    {
        [NSApp terminate: nil];
    }
}

- (IBAction) endOpenPanel: (id) sender;
{
    [NSApp stopModalWithCode: kMameRunGame];
}

- (IBAction) cancelOpenPanel: (id) sender;
{
    [NSApp stopModalWithCode: kMameCancelGame];
}

- (IBAction) hideOpenPanel: (id) sender;
{
    [mGameLoading stopAnimation: nil];
    [mOpenPanel orderOut: [mMameView window]];
}

- (IBAction) setActualSize: (id) sender;
{
    NSSize naturalSize = [mMameView naturalSize];
    [self setViewSize: naturalSize];
}

- (IBAction) setOptimalSize: (id) sender;
{
    [self setViewSize: [mMameView optimalSize]];
}

- (IBAction) setDoubleSize: (id) sender;
{
    NSSize naturalSize = [mMameView naturalSize];
    naturalSize.width *= 2;
    naturalSize.height *= 2;
    [self setViewSize: naturalSize];
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

//=========================================================== 
//  fullScreen 
//=========================================================== 
- (BOOL) fullScreen
{
    return [mMameView fullScreen];
}

- (void) setFullScreen: (BOOL) fullScreen;
{
    [mMameView setFullScreen: fullScreen];
}

- (NSArray *) previousGames;
{
    return mPreviousGames;
}

@end

@implementation MameController (Private)

- (void) setViewSize: (NSSize) newViewSize;
{
    NSWindow * window = [mMameView window];
    NSRect currentWindowFrame = [window frame];
    NSSize currentWindowSize = currentWindowFrame.size;
    NSSize currentViewSize = [mMameView frame].size;
    float diffWidth = currentWindowSize.width - currentViewSize.width;
    float diffHeight = currentWindowSize.height - currentViewSize.height;

    NSRect newWindowFrame = currentWindowFrame;
    newWindowFrame.size.width = newViewSize.width + diffWidth;
    newWindowFrame.size.height = newViewSize.height + diffHeight;

    // Adjust origin so title bar stays in same location
    newWindowFrame.origin.y +=
        currentWindowFrame.size.height - newWindowFrame.size.height;

    [window setFrame: newWindowFrame
             display: YES
             animate: YES];
}

- (void) viewNaturalSizeDidChange: (NSNotification *) notification;
{
    [self setOptimalSize: nil];
    NSWindow * window = [mMameView window];
    [window center];
    [window makeKeyAndOrderFront: nil];
}

- (void) setUpDefaultPaths;
{
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    [[mMameView fileManager] setPath: [myBundle resourcePath] forType: FILETYPE_FONT];
}

- (NSString *) getGameNameToRun;
{
    NSString * gameToRun = 
        [[NSUserDefaults standardUserDefaults] stringForKey: kMameGame];
    if (gameToRun == nil)
    {
        [self raiseOpenPanel: nil];
        gameToRun = [mGameTextField stringValue];
    }
    return gameToRun;
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

- (void) updatePreviousGames: (NSString *) gameName;
{
    [self willChangeValueForKey: @"previousGames"];
    [mPreviousGames removeObject: gameName];
    [mPreviousGames insertObject: gameName atIndex: 0];
    [self didChangeValueForKey: @"previousGames"];
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: mPreviousGames forKey: kMamePreviousGames];
    [defaults synchronize];
}

@end
