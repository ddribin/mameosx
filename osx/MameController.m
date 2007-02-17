/*
 * Copyright (c) 2006 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "MameController.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <MameKit/MameKit.h>
#import "CustomMameFilters.h"
#import "MameConfiguration.h"
#import "VersionChecker.h"
#import "PreferencesWindowController.h"
#import "MamePreferences.h"
#import "RomAuditWindowController.h"
#import "AudioEffectWindowController.h"
#import "JRLog.h"

#include <mach/mach_time.h>
#include <unistd.h>
#include "osd_osx.h"            

static const int kMameRunGame = 0;
static const int kMameCancelGame = 1;
static const int kMameMaxGamesInHistory = 100;

@interface MameController (Private)

- (void) syncWithUserDefaults;
- (void) setGameLoading: (BOOL) gameLoading;
- (void) setGameRunning: (BOOL) gameRunning;
- (void) setFrameSize: (NSSize) newFrameSize;
- (void) setViewSize: (NSSize) viewSize;
- (void) setSizeFromPrefereneces;
- (EffectFilter *) effectNamed: (NSString *) effectName;
- (void) initFilters;

- (NSSize) constrainFrameToAspectRatio: (NSSize) size;
- (NSSize) constrainFrameToIntegralNaturalSize: (NSSize) size;

- (void) initLogAttributes;
- (void) logMessage: (NSString *) message
     withAttributes: (NSDictionary *) attributes;

- (void) exitAlertDidEnd: (NSAlert *) aler
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

+ (void) initialize
{
    [[MamePreferences standardPreferences] registerDefaults];
}

- (id) init
{
    if (![super init])
        return nil;
    
    mOriginalLogger = [[self class] JRLogLogger];
    [[self class] setJRLogLogger: self];
   
    mConfiguration = [[MameConfiguration alloc] init];
    [self initFilters];
    
    [self initLogAttributes];

    sSleepAtExit =
        [[MamePreferences standardPreferences] sleepAtExit];
    atexit(exit_sleeper);
    
    return self;
}

- (void) awakeFromNib
{
    [mMameView setDelegate: self];

    [self setIsFiltered: NO];
    [self setCurrentFilterIndex: 0];
   
    [self setGameLoading: NO];
    [self setGameRunning: NO];

    MamePreferences * preferences = [MamePreferences standardPreferences];
    
    mGameName = [[preferences game] retain];
    mQuitOnError = (mGameName == nil)? NO : YES;
    if ([[[NSProcessInfo processInfo] arguments] count] > 1)
        [NSApp activateIgnoringOtherApps: YES];

    [self willChangeValueForKey: @"previousGames"];
    mPreviousGames = [[preferences previousGames] mutableCopy];
    if (mPreviousGames == nil)
        mPreviousGames = [[NSMutableArray alloc] init];
    [self didChangeValueForKey: @"previousGames"];
    
    if (NSClassFromString(@"SenTestCase") != nil)
        return;

    if ([preferences checkUpdatesAtStartup])
    {
        [mVersionChecker setVersionUrl: [preferences versionUrl]];
        [mVersionChecker checkForUpdatesInBackground];
    }
    
    NSWindow * window = [mMameView window];
    NSRect currentWindowFrame = [window frame];
    NSSize currentWindowSize = currentWindowFrame.size;
    NSSize currentViewSize = [mMameView frame].size;
    mExtraWindowSize.width = currentWindowSize.width - currentViewSize.width;
    mExtraWindowSize.height = currentWindowSize.height - currentViewSize.height;
}

- (void) applicationDidFinishLaunching: (NSNotification*) notification;
{
    if (NSClassFromString(@"SenTestCase") != nil)
        return;
    
    // Work around for an IB issue:
    // "Why does my bottom or top drawer size itself improperly?"
    // http://developer.apple.com/documentation/DeveloperTools/Conceptual/IBTips/Articles/FreqAskedQuests.html
    [mDrawer setContentSize: NSMakeSize(20, 60)];
    
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

- (MameView *) mameView;
{
    return mMameView;
}

- (MameConfiguration *) configuration;
{
    return mConfiguration;
}

- (IBAction) showPreferencesPanel: (id) sender;
{
    if (mPreferencesController == nil)
        mPreferencesController = [[PreferencesWindowController alloc] init];
    
    NSWindow * window = [mPreferencesController window];
    if (![window isVisible])
        [window center];
    [mPreferencesController showWindow: self];
}

- (IBAction) showAudioEffectsPanel: (id) sender;
{
    if (mAudioEffectsController == nil)
        mAudioEffectsController = [[AudioEffectWindowController alloc]
            initWithMameView: mMameView];
    
    NSWindow * window = [mAudioEffectsController window];
    [mAudioEffectsController showWindow: self];
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
        [mMameView setFilter: [mFilters objectAtIndex: mCurrentFilterIndex]];
    else
        [mMameView setFilter: nil];
}

- (int) currentFilterIndex;
{
    return mCurrentFilterIndex;
}

- (void) setCurrentFilterIndex: (int) currentFilterIndex;
{
    if (currentFilterIndex >= [mFilters count])
        return;
    
    NSMenuItem * item = [mEffectsMenu itemAtIndex: mCurrentFilterIndex];
    [item setState: NO];

    mCurrentFilterIndex = currentFilterIndex;
    if (mIsFiltered)
        [mMameView setFilter: [mFilters objectAtIndex: mCurrentFilterIndex]];
    
    item = [mEffectsMenu itemAtIndex: mCurrentFilterIndex];
    [item setState: YES];
}

- (IBAction) nextFilter: (id) sender;
{
    int nextFilter = mCurrentFilterIndex + 1;
    if (nextFilter < [mFilters count])
        [self setCurrentFilterIndex: nextFilter];
}

- (IBAction) previousFilter: (id) sender;
{
    int nextFilter = mCurrentFilterIndex - 1;
    if (nextFilter >= 0)
        [self setCurrentFilterIndex: nextFilter];
}        

- (IBAction) effectsMenuChanged: (id) sender;
{
    int filterIndex = [mEffectsMenu indexOfItem: sender];
    [self setCurrentFilterIndex: filterIndex];
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

#pragma mark -
#pragma mark Resizing

- (IBAction) resizeToActualSize: (id) sender;
{
    if (![mMameView fullScreen])
    {
        NSSize naturalSize = [mMameView naturalSize];
        [self setViewSize: naturalSize];
    }
}

- (IBAction) resizeToDoubleSize: (id) sender;
{
    if (![mMameView fullScreen])
    {
        NSSize naturalSize = [mMameView naturalSize];
        naturalSize.width *= 2;
        naturalSize.height *= 2;
        [self setViewSize: naturalSize];
    }
}

- (IBAction) resizeToOptimalSize: (id) sender;
{
    if (![mMameView fullScreen])
    {
        [self setViewSize: [mMameView optimalSize]];
    }
}

- (IBAction) resizeToMaximumIntegralSize: (id) sender;
{
    if (![mMameView fullScreen])
    {
        NSSize size = [[NSScreen mainScreen] visibleFrame].size;
        size = [self constrainFrameToIntegralNaturalSize: size];
        [self setFrameSize: size];
    }
}

- (IBAction) resizeToMaximumSize: (id) sender;
{
    if (![mMameView fullScreen])
    {
        NSSize size = [[NSScreen mainScreen] visibleFrame].size;
        size = [self constrainFrameToAspectRatio: size];
        [self setFrameSize: size];
    }
}

- (NSSize) windowWillResize: (NSWindow *) sender toSize: (NSSize) size
{
    if (sender != [mMameView window])
        return size;
    
    int flags = [[NSApp currentEvent] modifierFlags];
    if (!(flags & NSControlKeyMask))
    {
        if (flags & NSAlternateKeyMask)
        {
            size = [self constrainFrameToIntegralNaturalSize: size];
        }
        else
        {
            size = [self constrainFrameToAspectRatio: size];
        }
    }
    return size;
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

- (BOOL) linearFilter;
{
    return [mMameView linearFilter];
}

- (void) setLinearFilter: (BOOL) linearFilter;
{
    [mMameView setLinearFilter: linearFilter];
}

- (BOOL) audioEffectEnabled;
{
    return [mMameView audioEffectEnabled];
}

- (void) setAudioEffectEnabled: (BOOL) flag;
{
    [mMameView setAudioEffectEnabled: flag];
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

- (NSString *) loadingMessage;
{
    return mLoadingMessage;
}

- (IBAction) auditRoms: (id) sender;
{
    RomAuditWindowController * controller =
        [[RomAuditWindowController alloc] init];
    [controller autorelease];
    
    NSWindow * window = [controller window];
    [window center];
    [controller showWindow: self];
}

- (IBAction) showLogWindow: (id) sender;
{
    [mMameLogPanel makeKeyAndOrderFront: nil];
}

- (IBAction) clearLogWindow: (id) sender;
{
    NSTextStorage * textStorage = [mMameLogView textStorage];
    NSRange fullRange = NSMakeRange(0, [textStorage length]);
    [textStorage deleteCharactersInRange: fullRange];
}

- (IBAction) showReleaseNotes: (id) sender;
{
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    NSString * releaseNotes = 
        [myBundle pathForResource: @"release_notes" ofType: @"html"];
    [[NSWorkspace sharedWorkspace] openFile: releaseNotes];
}

- (void) logWithLevel: (JRLogLevel) callerLevel
             instance: (NSString*) instance
                 file: (const char*) file
                 line: (unsigned) line
             function: (const char*) function
              message: (NSString*) message;
{
    NSDictionary * logAttributes;
    switch (callerLevel)
    {
        case JRLogLevel_Debug:
            logAttributes = mLogDebugAttributes;
            break;
            
        case JRLogLevel_Info:
            logAttributes = mLogInfoAttributes;
            break;
            
        case JRLogLevel_Warn:
            logAttributes = mLogWarningAttributes;
            break;
            
        case JRLogLevel_Error:
        case JRLogLevel_Fatal:
            logAttributes = mLogErrorAttributes;
            break;
            
        default:
            logAttributes = mLogInfoAttributes;
    }
    
    [self logMessage: message withAttributes: logAttributes];
    
    [mOriginalLogger logWithLevel: callerLevel
                         instance: instance
                             file: file
                             line: line
                         function: function
                          message: message];
}

- (void) mameErrorMessage: (NSString *) message;
{
    NSLog(@"[E]: %@", message);
    [self logMessage: message withAttributes: mLogErrorAttributes];
}

- (void) mameWarningMessage: (NSString *) message;
{
    NSLog(@"[W]: %@", message);
    [self logMessage: message withAttributes: mLogWarningAttributes];
}

- (void) mameInfoMessage: (NSString *) message;
{
    NSLog(@"[I]: %@", message);
    [self logMessage: message withAttributes: mLogInfoAttributes];
}

- (void) mameDebugMessage: (NSString *) message;
{
    NSLog(@"[D]: %@", message);
    [self logMessage: message withAttributes: mLogDebugAttributes];
}

- (void) mameLogMessage: (NSString *) message;
{
    NSLog(@"[L]: %@", message);
    [self logMessage: message withAttributes: mLogInfoAttributes];
}

- (void) mameWillStartGame: (NSNotification *) notification;
{
    /*
     * Some how, setting game loading, before hiding panel causes the following
     * error:
     *
     * Assertion failure in -[NSThemeFrame lockFocus], AppKit.subproj/NSView.m:3248
     * lockFocus sent to a view whose window is deferred and does not yet have a
     * corresponding platform window
     */
    
    [self hideOpenPanel: nil];
    [self setGameLoading: NO];
    [self setGameRunning: YES];
    
    [self setSizeFromPrefereneces];
    NSWindow * window = [mMameView window];

    NSSize minSize = [mMameView naturalSize];
    minSize.width += mExtraWindowSize.width;
    minSize.height += mExtraWindowSize.height;
    [window setMinSize: minSize];
    
    [window setTitle: [NSString stringWithFormat: @"MAME: %@ [%@]",
        [mMameView gameDescription], mGameName]];
    [window center];

    
    if ([[MamePreferences standardPreferences] fullScreen])
        [mMameView setFullScreen: YES];
    
    // Open the window next run loop.  Need to do this, even in full screen
    // mode, so that the view gets focus.
    [window makeKeyAndOrderFront: nil];
}

- (void) mameDidFinishGame: (NSNotification *) notification;
{
    NSDictionary * userInfo = [notification userInfo];
    int exitStatus = [[userInfo objectForKey: MameExitStatusKey] intValue];
    if (exitStatus != MameExitStatusSuccess)
    {
        NSString * message;
        if (exitStatus == MameExitStatusFailedValidity)
        {
            message = @"Validity Checks Failed";
        }
        else if (exitStatus == MameExitStatusMissingFiles)
        {
            message = @"Some Files Were Missing";
        }
        else
        {
            message = @"A Fatal Error Occured";
        }
        
        if (mQuitOnError)
        {
            JRLogError(@"MAME finished with error: %@ (%d)", message,
                       exitStatus);
            [NSApp terminate: nil];
        }
        else
        {
            [mMameView setFullScreen: false];
            
            NSAlert * alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle: @"OK"];
            [alert setMessageText: message];
            [alert setInformativeText: @"View the MAME Log for details."];
            [alert setAlertStyle: NSCriticalAlertStyle];
            
            [alert beginSheetModalForWindow: [mMameView window]
                              modalDelegate: self
                             didEndSelector: @selector(exitAlertDidEnd:returnCode:contextInfo:)
                                contextInfo: nil];
            [alert release];
        }
    }
    else
    {
        [NSApp terminate: nil];
    }
}

@end

@implementation MameController (Private)

- (void) exitAlertDidEnd: (NSAlert *) aler
              returnCode: (int) returnCode
             contextInfo: (void *) contextInfo;
{
    NSWindow * window = [mMameView window];
    // Need to use delay to run outside modal loop
    [window performSelector: @selector(performClose:) withObject: nil
                 afterDelay: 0.0f];
}

- (MameFrameRenderingOption) frameRenderingOption: (NSString *) frameRendering;
{
    MameFrameRenderingOption frameRenderingOption = 
        [mMameView frameRenderingOptionDefault];
    if ([frameRendering isEqualToString: MameRenderFrameInOpenGLValue])
        frameRenderingOption = MameRenderFrameInOpenGL;
    else if ([frameRendering isEqualToString: MameRenderFrameInCoreImageValue])
        frameRenderingOption = MameRenderFrameInCoreImage;
    return frameRenderingOption;
}

- (BOOL) renderInCoreVideo: (NSString *) renderingThread;
{
    BOOL renderInCoreVideo = [mMameView renderInCoreVideoThreadDefault];
    if ([renderingThread isEqualToString: MameRenderInCoreVideoThreadValue])
        renderInCoreVideo = YES;
    else if ([renderingThread isEqualToString: MameRenderInMameThreadValue])
        renderInCoreVideo = NO;
    return renderInCoreVideo;
}

- (MameFullScreenZoom) fullScreenZoom: (NSString *) fullScreenZoomLevel;
{
    MameFullScreenZoom fullScreenZoom = MameFullScreenMaximum;
    if ([fullScreenZoomLevel isEqualToString: MameFullScreenIntegralValue])
        fullScreenZoom = MameFullScreenIntegral;
    else if ([fullScreenZoomLevel isEqualToString: MameFullScreenIndependentIntegralValue])
        fullScreenZoom = MameFullScreenIndependentIntegral;
    else if ([fullScreenZoomLevel isEqualToString: MameFullScreenStretchValue])
        fullScreenZoom = MameFullScreenStretch;
    return fullScreenZoom;
}

- (void) syncWithUserDefaults;
{
    MamePreferences * preferences = [MamePreferences standardPreferences];

    [self setThrottled: [preferences throttled]];
    [self setSyncToRefresh: [preferences syncToRefresh]];
    [self setLinearFilter: [preferences linearFilter]];

    [mMameView setAudioEnabled: [preferences soundEnabled]];
    
    NSString * frameRendering = [preferences frameRendering];
    [mMameView setFrameRenderingOption:
        [self frameRenderingOption: frameRendering]];
    
    NSString * renderingThread = [preferences renderingThread];
    [mMameView setRenderInCoreVideoThread:
        [self renderInCoreVideo: renderingThread]];
    
    NSString * fullScreenZoomLevel = [preferences fullScreenZoomLevel];
    [mMameView setFullScreenZoom:
        [self fullScreenZoom: fullScreenZoomLevel]];

    [mMameView setClearToRed: [preferences clearToRed]];
    [mMameView setKeepAspectRatio: [preferences keepAspect]];
    [mMameView setSwitchModesForFullScreen: [preferences switchResolutions]];
    
    [preferences copyToMameConfiguration: mConfiguration];
    
    if ([preferences smoothFont])
    {
        NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
        [mConfiguration setFontPath: [myBundle resourcePath]];
    }
    else
    {
        [mConfiguration setFontPath: @""];
    }
}

- (void) setGameLoading: (BOOL) gameLoading;
{
    mGameLoading = gameLoading;
}

- (void) setGameRunning: (BOOL) gameRunning;
{
    mGameRunning = gameRunning;
}

- (void) setFrameSize: (NSSize) newFrameSize;
{
    NSWindow * window = [mMameView window];
    NSRect currentWindowFrame = [window frame];
    
    NSRect newWindowFrame = currentWindowFrame;
    newWindowFrame.size = newFrameSize;
    
    // Adjust origin so title bar stays in same location
    newWindowFrame.origin.y +=
        currentWindowFrame.size.height - newWindowFrame.size.height;
    
    // Adjust origin to keep on screen
    NSScreen * screen = [[mMameView window] screen];
    NSRect screenFrame = [screen visibleFrame];
    newWindowFrame.origin.x = screenFrame.origin.x +
        (screenFrame.size.width - newWindowFrame.size.width) / 2;
    newWindowFrame.origin.y = screenFrame.origin.y +
        (screenFrame.size.height - newWindowFrame.size.height);
    
    [window setFrame: newWindowFrame
             display: YES
             animate: YES];
}

- (void) setViewSize: (NSSize) newViewSize;
{
    // Convert view size into frame size
    newViewSize.width += mExtraWindowSize.width;
    newViewSize.height += mExtraWindowSize.height;
    [self setFrameSize: newViewSize];
}

- (void) setSizeFromPrefereneces;
{
    NSString * zoomLevel = [[MamePreferences standardPreferences] windowedZoomLevel];
    if ([zoomLevel isEqualToString: MameZoomLevelActual])
    {
        [self resizeToActualSize: nil];
    }
    else if ([zoomLevel isEqualToString: MameZoomLevelDouble])
    {
        [self resizeToDoubleSize: nil];
    }
    else if ([zoomLevel isEqualToString: MameZoomLevelMaximum])
    {
        [self resizeToMaximumSize: nil];
    }
    else
    {
        [self resizeToMaximumIntegralSize: nil];
    }
}

- (EffectFilter *) effectNamed: (NSString *) effectName;
{
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    NSString * path = [myBundle pathForResource: effectName
                                         ofType: @"png"
                                    inDirectory: @"effects"];
    return [EffectFilter effectWithPath: path];
}

- (void) initFilters;
{
    mFilters = [[NSMutableArray alloc] init];
    
    MameFilter * mameFilter;
        
    [mFilters addObject: [self effectNamed: @"scanlines32x2"]];
    [mFilters addObject: [self effectNamed: @"aperture1x2rb"]];
    [mFilters addObject: [self effectNamed: @"aperture1x3rb"]];
    [mFilters addObject: [self effectNamed: @"aperture2x4rb"]];
    [mFilters addObject: [self effectNamed: @"aperture2x4bg"]];
    [mFilters addObject: [self effectNamed: @"aperture4x6"]];

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
}

- (NSSize) constrainFrameToAspectRatio: (NSSize) size;
{
    size.height -= mExtraWindowSize.height;
    size.width  -= mExtraWindowSize.width;
    
    size = [mMameView stretchedSize: size];

    size.height += mExtraWindowSize.height;
    size.width  += mExtraWindowSize.width;

    return size;
}

- (NSSize) constrainFrameToIntegralNaturalSize: (NSSize) size;
{
    size.height -= mExtraWindowSize.height;
    size.width  -= mExtraWindowSize.width;

    size = [mMameView integralStretchedSize: size];
    
    size.height += mExtraWindowSize.height;
    size.width  += mExtraWindowSize.width;
    return size;
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
        [self willChangeValueForKey: @"loadingMessage"];
        [mLoadingMessage release];
        mLoadingMessage = [[NSString alloc] initWithFormat:
            @"Loading %@", [mMameView gameDescription]];
        [self didChangeValueForKey: @"loadingMessage"];
        
        [self setGameLoading: YES];
        [self updatePreviousGames: mGameName];
        
        [mMameView start];
    }
    else
    {
        int matches[5];
        driver_get_approx_matches([mGameName UTF8String], ARRAY_LENGTH(matches), matches);
        NSMutableString * message = [NSMutableString stringWithString: @"Closest matches:"];
        int drvnum;
        for (drvnum = 0; drvnum < ARRAY_LENGTH(matches); drvnum++)
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
    
    MamePreferences * preferences = [MamePreferences standardPreferences];
    [preferences setPreviousGames: mPreviousGames];
    [preferences synchronize];
}

- (void) logMessage: (NSString *) message
     withAttributes: (NSDictionary *) attributes;
{
    NSString * messageWithNewline = [NSString stringWithFormat: @"%@\n", message];
    NSAttributedString * addendum =
        [[NSAttributedString alloc] initWithString: messageWithNewline
                                        attributes: attributes];
    NSTextStorage * textStorage = [mMameLogView textStorage];
    [textStorage appendAttributedString: addendum];
    NSRange endRange = NSMakeRange([textStorage length], 1);
    [mMameLogView scrollRangeToVisible: endRange];
    [addendum release];
}

- (void) initLogAttributes;
{
    NSFont * monaco = [NSFont fontWithName: @"Monaco" size: 10];
    mLogAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
        monaco, NSFontAttributeName,
        [NSColor blackColor], NSForegroundColorAttributeName,
        0];
    
    mLogErrorAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
        monaco, NSFontAttributeName,
        [NSColor redColor], NSForegroundColorAttributeName,
        0];
    mLogWarningAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
        monaco, NSFontAttributeName,
        [NSColor yellowColor], NSForegroundColorAttributeName,
        0];
    mLogInfoAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
        monaco, NSFontAttributeName,
        [NSColor blackColor], NSForegroundColorAttributeName,
        0];
    mLogDebugAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
        monaco, NSFontAttributeName,
        [NSColor blueColor], NSForegroundColorAttributeName,
        0];
}

@end

