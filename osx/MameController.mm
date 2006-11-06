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
#import "MameFilter.h"

#include <mach/mach_time.h>
#include <unistd.h>
#include "osd_osx.h"            

// MAME headers
extern "C" {
#include "driver.h"
#include "render.h"
}

@interface MameInputCenterFilter : MameFilter
{
}

- (id) initWithFilter: (CIFilter *) filter;
+ (MameInputCenterFilter *) filterWithFilter: (CIFilter *) filter;

@end

@implementation MameInputCenterFilter

- (id) initWithFilter: (CIFilter *) filter;
{
    if ([super initWithFilter: filter] == nil)
        return nil;
    
    return self;
}

+ (MameInputCenterFilter *) filterWithFilter: (CIFilter *) filter;
{
    return [[[self alloc] initWithFilter: filter] autorelease];
}

- (CIImage *) filterFrame: (CIImage *) inputImage size: (NSSize) size;
{
    [mFilter setValue: [CIVector vectorWithX: size.width/2 Y: size.height/2]
               forKey: @"inputCenter"];
    return [super filterFrame: inputImage size: size];
}

@end


@interface MameBumpDistortionFilter : MameFilter
{
    float mCenterX;
}

- (id) init;
+ (MameBumpDistortionFilter *) filter;

@end

@implementation MameBumpDistortionFilter

- (id) init;
{
    if ([super initWithFilter: [CIFilter filterWithName: @"CIBumpDistortion"]] == nil)
        return nil;
    
   [mFilter setDefaults];
   [mFilter setValue: [NSNumber numberWithFloat: 75]  
              forKey: @"inputRadius"];
   [mFilter setValue: [NSNumber numberWithFloat:  3.0]  
              forKey: @"inputScale"];
   mCenterX = 0;
    
    return self;
}

+ (MameBumpDistortionFilter *) filter;
{
    return [[[self alloc] init] autorelease];
}

- (CIImage *) filterFrame: (CIImage *) frame size: (NSSize) size;
{
    mCenterX += 2;
    if (mCenterX > (size.width - 0))
        mCenterX = 0;
    
    [mFilter setValue: [CIVector vectorWithX: mCenterX Y: size.height/2]
               forKey: @"inputCenter"];
    return [super filterFrame: frame size: size];
}

@end


NSString * kMamePreviousGames = @"PreviousGames";
NSString * kMameGame = @"Game";
NSString * kMameSleepAtExit = @"SleepAtExit";

static const int kMameRunGame = 0;
static const int kMameCancelGame = 1;

@interface MameController (Private)

- (void) setViewSize: (NSSize) viewSize;
- (void) viewNaturalSizeDidChange: (NSNotification *) notification;
- (void) setUpDefaultPaths;
- (void) initFilters;

#pragma mark -
#pragma mark Game Choosing

- (void) chooseGameAndStart;
- (NSString *) getGameNameToRun;
- (void) alertDidEnd: (NSAlert *) alert
          returnCode: (int) returnCode
         contextInfo: (void *) contextInfo;
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
    
    [self chooseGameAndStart];
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
    if (rc != kMameRunGame)
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

- (void) initFilters;
{
    mFilters = [[NSMutableArray alloc] init];
    
    CIFilter * filter;
    
    filter = [CIFilter filterWithName: @"CIGaussianBlur"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 3]  
              forKey: @"inputRadius"];
    [mFilters addObject: [MameFilter filterWithFilter: filter]];
    
    filter = [CIFilter filterWithName: @"CIZoomBlur"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 10]
              forKey: @"inputAmount"];
    [mFilters addObject: [MameInputCenterFilter filterWithFilter: filter]];

    [mFilters addObject: [MameBumpDistortionFilter filter]];

    filter = [CIFilter filterWithName:@"CICrystallize"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 3]
             forKey: @"inputRadius"];
    [mFilters addObject: [MameInputCenterFilter filterWithFilter: filter]];

    filter = [CIFilter filterWithName:@"CIPerspectiveTile"];
    [filter setDefaults];
    [mFilters addObject: [MameFilter filterWithFilter: filter]];
    
    filter = [CIFilter filterWithName:@"CIBloom"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 1.5f]
              forKey: @"inputIntensity"];
    [mFilters addObject: [MameFilter filterWithFilter: filter]];
    
    filter = [CIFilter filterWithName:@"CIEdges"];
    [filter setDefaults];
    [filter setValue: [NSNumber numberWithFloat: 5]  
              forKey: @"inputIntensity"];
    [mFilters addObject: [MameFilter filterWithFilter: filter]];
    
    mCurrentFilter = [mFilters objectAtIndex: 0];
}

#pragma mark -
#pragma mark Game Choosing


- (void) chooseGameAndStart;
{
    
    NSString * gameName = [self getGameNameToRun];
    if ([mMameView setGame: gameName])
    {
        [mGameLoading startAnimation: nil];
        [self updatePreviousGames: gameName];
        
        [mMameView start];
        [self hideOpenPanel: nil];
    }
    else
    {
        NSLog(@"Game not found: %@", gameName);
        int matches[5];
        driver_get_approx_matches([gameName UTF8String], ARRAY_LENGTH(matches), matches);
        NSMutableString * message = [NSMutableString stringWithString: @"Closest matches:"];
        for (int drvnum = 0; drvnum < ARRAY_LENGTH(matches); drvnum++)
        {
            if (matches[drvnum] != -1)
            {
                [message appendFormat: @"\n%s [%s]",
                    drivers[matches[drvnum]]->name,
                    drivers[matches[drvnum]]->description];
            }
        }
        
        NSAlert * alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle: @"Try Again"];
        [alert addButtonWithTitle: @"Quit"];
        [alert setMessageText:
            [NSString stringWithFormat: @"Game not found: %@", gameName]];
        [alert setInformativeText: message];
        [alert setAlertStyle: NSWarningAlertStyle];
        [alert beginSheetModalForWindow: mOpenPanel
                          modalDelegate: self
                         didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo: nil];
    }
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

- (void) alertDidEnd: (NSAlert *) alert
          returnCode: (int) returnCode
         contextInfo: (void *) contextInfo;
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [self performSelector: @selector(chooseGameAndStart) withObject: nil
                   afterDelay: 0.0f];
    }
    else
    {
        [NSApp terminate: nil];
    }
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

