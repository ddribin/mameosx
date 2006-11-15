//
//  MameController.m
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import "MamePreferencesController.h"
#import "MameController.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <MameKit/MameKit.h>
#import "CustomMameFilters.h"

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
static const int kMameMaxGamesInHistory = 100;

@interface MameController (Private)

- (void) syncWithUserDefaults;
- (void) setGameLoading: (BOOL) gameLoading;
- (void) setGameRunning: (BOOL) gameRunning;
- (void) setViewSize: (NSSize) viewSize;
- (void) setUpDefaultPaths;
- (void) initFilters;
- (void) logRomMessage: (NSString *) message;
- (void) logAlertDidEnd: (NSAlert *) alert
            returnCode: (int) returnCode
           contextInfo: (void *) contextInfo;

#pragma mark -
#pragma mark Game Choosing

- (void) chooseGameAndStart;
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
    
    NSFont * monaco = [NSFont fontWithName: @"Monaco" size: 10];
    mLogAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
        monaco, NSFontAttributeName,
        [NSColor blackColor], NSForegroundColorAttributeName,
        0];

    sSleepAtExit =
        [[NSUserDefaults standardUserDefaults] boolForKey: kMameSleepAtExit];
    atexit(exit_sleeper);
    
    return self;
}

- (void) awakeFromNib
{
    [mMameView setDelegate: self];

    [self setGameLoading: NO];
    [self setGameRunning: NO];

    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    
    mGameName = [[defaults stringForKey: kMameGame] retain];
    mQuitOnError = (mGameName == nil)? NO : YES;
    if ([[[NSProcessInfo processInfo] arguments] count] > 1)
        [NSApp activateIgnoringOtherApps: YES];

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
    [self syncWithUserDefaults];
    
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

- (BOOL)windowShouldClose: (id) sender;
{
    [NSApp terminate: nil];
    return YES;
}

- (MameConfiguration *) configuration;
{
    return mConfiguration;
}

- (IBAction) showPreferencesPanel: (id) sender;
{
    if (mPreferencesController == nil)
        mPreferencesController = [[MamePreferencesController alloc] init];
    
    NSWindow * window = [mPreferencesController window];
    if (![window isVisible])
        [window center];
    [mPreferencesController showWindow: self];
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
    [mOpenPanel center];
    [mOpenPanel makeKeyAndOrderFront: nil];
}

- (IBAction) endOpenPanel: (id) sender;
{
    mGameName = [[mGameTextField stringValue] retain];
    [self chooseGameAndStart];
}

- (IBAction) cancelOpenPanel: (id) sender;
{
    [NSApp terminate: nil];
}

- (IBAction) hideOpenPanel: (id) sender;
{
    [mOpenPanel orderOut: nil];
}

- (IBAction) resizeToActualSize: (id) sender;
{
    NSSize naturalSize = [mMameView naturalSize];
    [self setViewSize: naturalSize];
}

- (IBAction) resizeToDoubleSize: (id) sender;
{
    NSSize naturalSize = [mMameView naturalSize];
    naturalSize.width *= 2;
    naturalSize.height *= 2;
    [self setViewSize: naturalSize];
}

- (IBAction) resizeToOptimalSize: (id) sender;
{
    [self setViewSize: [mMameView optimalSize]];
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

- (BOOL) isGameLoading;
{
    return mGameLoading;
}

- (BOOL) isGameRunning;
{
    return mGameRunning;
}

- (IBAction) showRomLoadingLog: (id) sender;
{
    [mRomLoadingLogPanel makeKeyAndOrderFront: nil];
}

- (void) mameRomLoadingMessage: (NSString *) name
                    romsLoaded: (int) romsLoaded
                      romCount: (int) romCount;
{
    [self logRomMessage: [NSString stringWithFormat: @"Loading: %@", name]];
}

- (void) mameRomLoadingFinishedWithErrors: (BOOL) errors
                             errorMessage: (NSString *) errorMessage;
{
    [self logRomMessage: @"Loading: Done"];
    if (errors)
    {
        [self logRomMessage: @"\nErrors:"];
        [self logRomMessage: errorMessage];

        NSAlert * alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText: @"ROM Loading Error"];
        [alert setInformativeText: @"View the ROM Loading Log for details."];
        [alert setAlertStyle: NSCriticalAlertStyle];

        [alert beginSheetModalForWindow: [mMameView window]
                          modalDelegate: self
                         didEndSelector: @selector(logAlertDidEnd:returnCode:contextInfo:)
                            contextInfo: nil];
        [alert release];
    }
}

- (void) mameWillStartGame: (NSNotification *) notification;
{
    /*
     * Some how, setting game loading, before hiding panel causes the following error:
     *
     * Assertion failure in -[NSThemeFrame lockFocus], AppKit.subproj/NSView.m:3248
     * lockFocus sent to a view whose window is deferred and does not yet have a
     * corresponding platform window
     */
    
    [self hideOpenPanel: nil];
    [self setGameLoading: NO];
    [self setGameRunning: YES];
    
    [self resizeToOptimalSize: nil];
    NSWindow * window = [mMameView window];
    [window center];

    // Open the window next run loop
    [window makeKeyAndOrderFront: nil];
}

- (void) mameDidFinishGame: (NSNotification *) notification;
{
    [NSApp terminate: nil];
}

@end

@implementation MameController (Private)

- (void) syncWithUserDefaults;
{
    [mConfiguration loadUserDefaults];
    [mMameView setAudioEnabled: [mConfiguration soundEnabled]];
    [self setThrottled: [mConfiguration throttled]];
    [self setSyncToRefresh: [mConfiguration syncToRefresh]];
    [mMameView setRenderInCoreVideoThread: [mConfiguration renderInCV]];
    [mMameView setClearToRed: [mConfiguration clearToRed]];
}

- (void) setGameLoading: (BOOL) gameLoading;
{
    mGameLoading = gameLoading;
}

- (void) setGameRunning: (BOOL) gameRunning;
{
    mGameRunning = gameRunning;
}

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
    if (mGameName == nil)
    {
        [self raiseOpenPanel: nil];
        return;
    }

    // User defaults could change between startup and now
    [self syncWithUserDefaults];
    if ([mMameView setGame: mGameName])
    {
        [self setGameLoading: YES];
        [self updatePreviousGames: mGameName];
        
        [mMameView start];
    }
    else
    {
        int matches[5];
        driver_get_approx_matches([mGameName UTF8String], ARRAY_LENGTH(matches), matches);
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
        
        if (mQuitOnError)
        {
            NSLog(@"Game not found: %@\n%@", mGameName, message);
            [NSApp terminate: nil];
        }
        else
        {
        NSAlert * alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle: @"Try Again"];
        // [alert addButtonWithTitle: @"Quit"];
        [alert setMessageText:
            [NSString stringWithFormat: @"Game not found: %@", mGameName]];
        [alert setInformativeText: message];
        [alert setAlertStyle: NSWarningAlertStyle];
        [alert beginSheetModalForWindow: mOpenPanel
                          modalDelegate: self
                         didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo: nil];

        }
    }
}

- (void) alertDidEnd: (NSAlert *) alert
          returnCode: (int) returnCode
         contextInfo: (void *) contextInfo;
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [mGameName release];
        mGameName = nil;
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
    {
        [mPreviousGames removeObject: gameName];
        [mPreviousGames insertObject: gameName atIndex: 0];
        
        unsigned numberOfGames = [mPreviousGames count];
        if (numberOfGames > kMameMaxGamesInHistory)
        {
            unsigned length = numberOfGames - kMameMaxGamesInHistory;     
            [mPreviousGames removeObjectsInRange:
                NSMakeRange(kMameMaxGamesInHistory, length)];
        }
    }
    [self didChangeValueForKey: @"previousGames"];
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: mPreviousGames forKey: kMamePreviousGames];
    [defaults synchronize];
}

- (void) logRomMessage: (NSString *) message;
{
    NSString * messageWithNewline = [NSString stringWithFormat: @"%@\n", message];
    NSAttributedString * addendum =
        [[NSAttributedString alloc] initWithString: messageWithNewline
                                        attributes: mLogAttributes];
    NSTextStorage * textStorage = [mRomLoadingLog textStorage];
    [textStorage appendAttributedString: addendum];
    NSRange endRange = NSMakeRange([textStorage length], 1);
    [mRomLoadingLog scrollRangeToVisible: endRange];
    [addendum release];
}

- (void) logAlertDidEnd: (NSAlert *) alert
             returnCode: (int) returnCode
            contextInfo: (void *) contextInfo;
{
    NSWindow * window = [mMameView window];
    // Need to use delay to run outside modal loop
    [window performSelector: @selector(performClose:) withObject: nil
               afterDelay: 0.0f];
}

@end

