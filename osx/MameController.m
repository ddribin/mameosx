/*
 * Copyright (c) 2006-2007 Dave Dribin
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
#import "MameConfiguration.h"
#import "VersionChecker.h"
#import "PreferencesWindowController.h"
#import "MamePreferences.h"
#import "RomAuditWindowController.h"
#import "AudioEffectWindowController.h"
#import "BackgroundUpdater.h"
#import "JRLog.h"
#import "GameMO.h"
#import "GroupMO.h"
#import "RBSplitView.h"

#include <mach/mach_time.h>
#include <unistd.h>
#include "osd_osx.h"

static const int kMameRunGame = 0;
static const int kMameCancelGame = 1;
static const int kMameMaxGamesInHistory = 100;

@interface MameController (Private)

- (void) updatePredicate;
- (void) syncWithUserDefaults;
- (void) setGameLoading: (BOOL) gameLoading;
- (void) setGameRunning: (BOOL) gameRunning;
- (void) setFrameSize: (NSSize) newFrameSize;
- (void) setViewSize: (NSSize) viewSize;
- (void) setSizeFromPrefereneces;
- (void) initVisualEffects;
- (void) initVisualEffectsMenu;
- (void) updateGameFilterMenu;

- (NSSize) constrainFrameToAspectRatio: (NSSize) size;
- (NSSize) constrainFrameToIntegralNaturalSize: (NSSize) size;

- (void) initLogAttributes;
- (void) logMessage: (NSString *) message
     withAttributes: (NSDictionary *) attributes;

- (void) exitAlertDidEnd: (NSAlert *) aler
              returnCode: (int) returnCode
             contextInfo: (void *) contextInfo;
#pragma mark -
#pragma mark Folders

- (NSString *) applicationSupportFolder;
- (NSString *) favoritesFile;

#pragma mark -
#pragma mark Game Choosing

- (void) chooseGameAndStart;
- (void) alertDidEnd: (NSAlert *) alert
          returnCode: (int) returnCode
         contextInfo: (void *) contextInfo;
- (void) updatePreviousGames: (NSString *) gameName;

- (void) registerForUrls;
- (void) getUrl: (NSAppleEventDescriptor *) event
 withReplyEvent: (NSAppleEventDescriptor *) replyEvent;

#pragma mark -
#pragma mark Favorites

- (GroupMO *) favoritesGroup;

- (void) exportFavoritesToFile: (NSString *) file
                   skipIfEmpty: (BOOL) skipIfEmpty;

- (void) importFavoritesFromFile: (NSString *) file;

@end

static BOOL sSleepAtExit = NO;

static void exit_sleeper()
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
    [self registerForUrls];
   
    mConfiguration = [MameConfiguration defaultConfiguration];
    [self initVisualEffects];
    
    [self initLogAttributes];

    sSleepAtExit =
        [[MamePreferences standardPreferences] sleepAtExit];
    atexit(exit_sleeper);
    
    gameSortDescriptors = [[[MamePreferences standardPreferences] gamesSortDescriptors] retain];
    mShowClones = YES;
    
    mUpdater = [[BackgroundUpdater alloc] initWithMameController: self];
    
    return self;
}

- (void) awakeFromNib
{
    [mOpenPanel setToolbar: mToolbar];
    [mGamesTable setDoubleAction: @selector(endOpenPanel:)];

    /*
     * By setting the autosave name here, rather than the NIB, we can save
     * the orignal frame size. Otherwise, the autosave clobbers the values
     * from the NIB.
     */
    mOriginalOpenFrame = [mOpenPanel frame];
    [mOpenPanel setFrameAutosaveName: @"OpenWindow"];
    
    [mMameView setDelegate: self];

    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    NSString * screenshotComposition = 
        [myBundle pathForResource: @"screenshot" ofType: @"qtz"];
    [mScreenshotView loadCompositionFromFile: screenshotComposition];
    [self bind: @"selectedGames"
      toObject: mGamesController
   withKeyPath: @"selectedObjects"
       options: nil];
    
    // The panel should be a utility panel, but not floating.  This cannot
    // be set in Interface Builder.
    [mInfoPanel setFloatingPanel: NO];
    [mInfoAuditNotes setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
    
    [mAllGamesController addObserver: self
                          forKeyPath: @"arrangedObjects"
                             options: 0
                             context: nil];
    
    [self initVisualEffectsMenu];
    [self setVisualEffectEnabled: NO];
    [self setCurrentEffectIndex: 0];
   
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
    
    [[mFavoriteColumn headerCell] setImage: [NSImage imageNamed: @"favorite-16"]];
    
    [self setGameFilterIndex: [preferences gameFilterIndex]];
    [self updatePredicate];
    [mUpdater start];
}

#pragma mark -
#pragma mark Core Data Support

- (void) handleCoreDataError: (NSError *) error;
{
    JRLogError(@"Received Core Data error: %@", error);
    [[NSApplication sharedApplication] presentError:error];
}

+ (void)setMetadata:(NSString *)value forKey:(NSString *)key inStoreWithURL:(NSURL *)url inContext:(NSManagedObjectContext *)context
{
    NSPersistentStoreCoordinator *coordinator = [context persistentStoreCoordinator];
    id store = [coordinator persistentStoreForURL: url];
    NSMutableDictionary *metadata = [[coordinator metadataForPersistentStore: store] mutableCopy];
    [metadata setValue: value forKey: key];
    [coordinator setMetadata: metadata forPersistentStore: store];
    [metadata release];
}

/**
Creates, retains, and returns the managed object model for the application 
 by merging all of the models found in the application bundle and all of the 
 framework bundles.
 */

- (NSManagedObjectModel *) managedObjectModel
{
    
    if (managedObjectModel != nil)
    {
        return managedObjectModel;
    }
	
    NSMutableSet *allBundles = [[NSMutableSet alloc] init];
    [allBundles addObject: [NSBundle mainBundle]];
    [allBundles addObjectsFromArray: [NSBundle allFrameworks]];
    
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]] retain];
    [allBundles release];
    
    return managedObjectModel;
}


/**
Returns the persistent store coordinator for the application.  This 
 implementation will create and return a coordinator, having added the 
 store for the application to it.  (The folder for the store is created, 
                                    if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator
{
    if (persistentStoreCoordinator != nil)
    {
        return persistentStoreCoordinator;
    }
    
    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [self applicationSupportFolder];
    if (![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL])
    {
        [fileManager createDirectoryAtPath:applicationSupportFolder attributes: nil];
    }
    
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent:
        @"MAME OS X.db"]];
        // @"MAME OS X.xml"]];
    NSDictionary * storeInfo =
        [NSPersistentStoreCoordinator metadataForPersistentStoreWithURL: url error: &error];
    
    if(![[storeInfo valueForKey: @"viewVersion"] isEqualToString: @"Version 4"])
    {
        [fileManager removeFileAtPath: [url path] handler: nil];
        [fileManager createDirectoryAtPath:applicationSupportFolder attributes: nil];
    }
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType: 
        // NSXMLStoreType
        NSSQLiteStoreType
                                                  configuration: nil URL: url
                                                        options: nil error: &error])
    {
        [self handleCoreDataError: error];
    }    
    
    if (managedObjectContext == nil)
    {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: persistentStoreCoordinator];
        [[self class] setMetadata: @"Version 4" forKey: @"viewVersion"
                   inStoreWithURL: url inContext: managedObjectContext];
    }
    
    return persistentStoreCoordinator;
}
/**
Returns the managed object context for the application (which is already
                                                        bound to the persistent store coordinator for the application.) 
 */

- (NSManagedObjectContext *) managedObjectContext
{
    if (managedObjectContext == nil)
    {
        [self persistentStoreCoordinator];
    }

    return managedObjectContext;
}

/**
Returns the NSUndoManager for the application.  In this case, the manager
 returned is that of the managed object context for the application.
 */

- (NSUndoManager *) windowWillReturnUndoManager: (NSWindow *) window
{
    return [[self managedObjectContext] undoManager];
}

/**
Performs the save action for the application, which is to send the save:
 message to the application's managed object context.  Any encountered errors
 are presented to the user.
 */

- (IBAction) saveAction: (id) sender
{
    
    NSError *error = nil;
    if (![[self managedObjectContext] save: &error])
    {
        [self handleCoreDataError: error];
    }
}

- (void) rearrangeObjects;
{
    [mGamesController rearrangeObjects];
}

- (id) newGame;
{
    return [mGamesController newObject];
}

#pragma mark -
#pragma mark Toolbar Delegate Methods

/*
 * Need to setup these bindings programmatically, because doing it in IB
 * messes up the enabled state of items in the Confugration sheet.  Those
 * items should always be enabled, rather than track via bindings.  Setting
 * up bindings only when added to the toolbar fixes this.
 */

- (void) toolbarWillAddItem: (NSNotification *) note
{
    NSToolbarItem * item = [[note userInfo] objectForKey: @"item"];
    NSString * identifier = [item itemIdentifier];
    if ([identifier isEqualToString: @"Play"] ||
        [identifier isEqualToString: @"Favorite"])
    {
        [item bind: @"enabled"
          toObject: mGamesController
       withKeyPath: @"selectionIndexes.count"
           options: nil];
    }
    else if ([identifier isEqualToString: @"Search"])
    {
        [[item view] bind: @"value"
          toObject: self
       withKeyPath: @"filterString"
           options: nil];
    }
    else if ([identifier isEqualToString: @"Filter"])
    {
        [[item view] bind: @"selectedIndex"
          toObject: self
       withKeyPath: @"gameFilterIndex"
           options: nil];
    }
}

- (void) toolbarDidRemoveItem: (NSNotification *) note
{
    NSToolbarItem * item = [[note userInfo] objectForKey: @"item"];
    NSString * identifier = [item itemIdentifier];
    if ([identifier isEqualToString: @"Play"] ||
        [identifier isEqualToString: @"Favorite"])
    {
        [item unbind: @"enabled"];
    }
    else if ([identifier isEqualToString: @"Search"])
    {
        [item unbind: @"value"];
    }
    else if ([identifier isEqualToString: @"Filter"])
    {
        [item unbind: @"selectedIndex"];
    }
}

#pragma mark -
#pragma mark Table View Delegate

- (NSString *) tableView: (NSTableView *) tableView
          toolTipForCell: (NSCell *)aCell
                    rect: (NSRectPointer)rect
             tableColumn: (NSTableColumn *)aTableColumn
                     row: (int)row
           mouseLocation: (NSPoint)mouseLocation;
{
    GameMO * game = [[mGamesController arrangedObjects] objectAtIndex: row];
    return [game displayName];
}

- (void)tableView: (NSTableView *)tableView
  willDisplayCell: (id)cell
   forTableColumn: (NSTableColumn *)tableColumn
              row: (int)rowIndex;
{
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    // The background updater sets the status, too.  Give it priority
    if ([mUpdater isRunning])
        return;
    
    NSArray * selectedGames = [mGamesController selectedObjects];

    NSString * status = @"";
    if ((selectedGames != nil) && ([selectedGames count] != 0))
    {
        GameMO * game = [selectedGames objectAtIndex: 0];
        status = [game displayName];
    }
    [self setStatusText: status];
}

#pragma mark -
#pragma mark Split View


// This makes it possible to drag the first divider around by the dragView.
- (unsigned int)splitView:(RBSplitView*)sender dividerForPoint:(NSPoint)point inSubview:(RBSplitSubview*)subview {
	if (subview==mGameSplit) {
		if ([mDragView mouse:[mDragView convertPoint:point fromView:sender] inRect:[mDragView bounds]]) {
			return 0;	// [firstSplit position], which we assume to be zero
		}
	} else if (subview==mScreenshotSplit) {
        //		return 1;
	}
	return NSNotFound;
}

// This changes the cursor when it's over the dragView.
- (NSRect)splitView:(RBSplitView*)sender cursorRect:(NSRect)rect forDivider:(unsigned int)divider {
	if (divider==0) {
		[sender addCursorRect:[mDragView convertRect:[mDragView bounds] toView:sender] cursor:[RBSplitView cursor:RBSVVerticalCursor]];
	}
	return rect;
}

- (IBAction) toggleScreenshot: (id) sender;
{
    // Not sure which behavior I like better, yet...
#if 0
    if ([mScreenshotSplit isCollapsed])
        [mScreenshotSplit expand];
    else
        [mScreenshotSplit collapse];
#else
    if ([mScreenshotSplit isHidden])
        [mScreenshotSplit setHidden: NO];
    else
        [mScreenshotSplit setHidden: YES];
#endif
}

- (IBAction) restoreOpenFrame: (id) sender;
{
    [NSWindow removeFrameUsingName: [mOpenPanel frameAutosaveName]];
    [mOpenPanel orderOut: self];
    [mOpenPanel setFrame: mOriginalOpenFrame display: NO];
    [mOpenPanel center];
    [mOpenPanel makeKeyAndOrderFront: self];
}

#pragma mark -

- (void) setFilterString: (NSString *) filterString;
{
    [filterString retain];
    [mFilterString release];
    mFilterString = filterString;
    [self updatePredicate];
}

- (NSString *) filterString;
{
    return mFilterString;
}

- (IBAction) gameFilterAction: (id) sender;
{
    [self setGameFilterIndex: [sender tag]];
}

- (void) setGameFilterIndex: (int) gameFilterIndex;
{
    mGameFilterIndex = gameFilterIndex;
#if 0
    static NSTableColumn * mSavedFavoritesColumn = nil;
    static BOOL mShouldRestoreFavoritesColumn = NO;
    if (mGamesTable == nil)
    {
        mSavedFavoritesColumn = [mFavoriteColumn retain];
        mGamesTable = [[mFavoriteColumn tableView] retain];
        [mGamesTable sizeLastColumnToFit];
    }
    if (mGameFilterIndex == 2)
    {
        [mGamesTable removeTableColumn: mSavedFavoritesColumn];
        mShouldRestoreFavoritesColumn = YES;
    }
    else
    {
        if (mShouldRestoreFavoritesColumn)
        {
            [mGamesTable addTableColumn: mSavedFavoritesColumn];
            mShouldRestoreFavoritesColumn = NO;
        }
    }
#endif
    [self willChangeValueForKey: @"matchingGames"];
    [self didChangeValueForKey: @"matchingGames"];
    [self updatePredicate];
    [self updateGameFilterMenu];

    MamePreferences * preferences = [MamePreferences standardPreferences];
    [preferences setGameFilterIndex: mGameFilterIndex];
    [preferences synchronize];
}

- (int) gameFilterIndex;
{
    return mGameFilterIndex;
}

//=========================================================== 
//  showClones 
//=========================================================== 
- (BOOL) showClones
{
    return mShowClones;
}

- (void) setShowClones: (BOOL) flag
{
    if (mShowClones == flag)
        return;
    
    mShowClones = flag;
    [self updatePredicate];
}

- (IBAction) toggleFavorite: (id) sender;
{
    GroupMO * favorites = [self favoritesGroup];
    
    NSArray * games = [mGamesController selectedObjects];
    [games makeObjectsPerformSelector: @selector(toggleGroupMembership:)
                           withObject: favorites];
    // [self saveAction: nil];
}

- (IBAction) exportFavorites: (id) sender;
{
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    NSArray * types = [NSArray arrayWithObject: @"plist"];
    [savePanel setAllowedFileTypes: types];
    
    int result = [savePanel runModal];
    if (result != NSOKButton)
        return;
    
    [self exportFavoritesToFile: [savePanel filename] skipIfEmpty: NO];
}

- (IBAction) importFavorites: (id) sender;
{
    NSOpenPanel * openPanel = [NSOpenPanel openPanel];
    NSArray * types = [NSArray arrayWithObject: @"plist"];
    int result = [openPanel runModalForTypes: types];
    if (result != NSOKButton)
        return;
    
    [self importFavoritesFromFile: [openPanel filename]];
}

//=========================================================== 
// - selectedGames
//=========================================================== 
- (NSArray *) selectedGames
{
    return mSelectedGames; 
}

//=========================================================== 
// - setSelectedGames:
//=========================================================== 
- (void) setSelectedGames: (NSArray *) theSelectedGames
{
    if (mSelectedGames == theSelectedGames)
        return;
    
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    NSString * screenshotDir = [[myBundle resourcePath] stringByAppendingPathComponent: @"empty_screenshot"];
    [mSelectedGames release];
    mSelectedGames = [theSelectedGames retain];
    GameMO * selectedGame = nil;
    if ([mSelectedGames count] == 1)
        selectedGame = [mSelectedGames objectAtIndex: 0];
    
    if (selectedGame != nil)
    {
        NSString * dir = [[MamePreferences standardPreferences] snapshotDirectory];
        dir = [dir stringByAppendingPathComponent: [selectedGame shortName]];
        NSFileManager * manager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        if ([manager fileExistsAtPath: dir isDirectory: &isDirectory])
        {
            screenshotDir = dir;
        }
    }
    [mScreenshotView setValue: screenshotDir forInputKey: @"Image_Folder_Path"];
}

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object 
                         change: (NSDictionary *) change
                        context: (void *) context;
{
    if ((object == mAllGamesController) &&
        [keyPath isEqualToString: @"arrangedObjects"])
    {
        [self willChangeValueForKey: @"matchingGames"];
        [self didChangeValueForKey: @"matchingGames"];
    }
}

- (NSArray *) matchingGames;
{
    if (mGameFilterIndex != 2)
    {
        return [mAllGamesController arrangedObjects];
    }
    else
    {
        GroupMO * favorites = [self favoritesGroup];
        return [[favorites membersSet] allObjects];
    }
}

- (IBAction) refreshGames: (id) sender;
{
    [self willChangeValueForKey: @"matchingGames"];
    [self didChangeValueForKey: @"matchingGames"];
    [mGamesController rearrangeObjects];
}

- (void) rearrangeGames;
{
    [mGamesController rearrangeObjects];
}

//=========================================================== 
//  statusText 
//=========================================================== 
- (NSString *) statusText
{
    return mStatusText; 
}

- (void) setStatusText: (NSString *) theStatusText
{
    if (mStatusText != theStatusText)
    {
        [mStatusText release];
        mStatusText = [theStatusText retain];
    }
}

//=========================================================== 
// - canAuditGames
//=========================================================== 
- (BOOL) canAuditGames
{
    return mCanAuditGames;
}

//=========================================================== 
// - setCanAuditGames:
//=========================================================== 
- (void) setCanAuditGames: (BOOL) flag
{
    mCanAuditGames = flag;
}

#pragma mark -
#pragma mark Background Callbacks

- (void) backgroundUpdateWillStart;
{
    [mProgressIndicator setIndeterminate: YES];
    [mProgressIndicator startAnimation: self];
}

- (void) backgroundUpdateWillBeginAudits: (unsigned) totalAudits;
{
    [mProgressIndicator setIndeterminate: NO];
    [mProgressIndicator setMaxValue: totalAudits];
    [mProgressIndicator setDoubleValue: 0];
}

- (void) backgroundUpdateAuditStatus: (unsigned) numberCompleted;
{
    [mProgressIndicator setDoubleValue: numberCompleted];
}

- (void) backgroundUpdateWillFinish;
{
    [mProgressIndicator setIndeterminate: YES];
    [mProgressIndicator stopAnimation: self];
}

#pragma mark -
#pragma mark Application Delegates

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

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) sender
{
    NSError * error;
    NSApplicationTerminateReply reply = NSTerminateNow;
    
    if (managedObjectContext != nil)
    {
        // Backup the Favorites list.  Skip it if it's empty, to avoid
        // overwriting a valid backup on accidental DB erasure.
        [self exportFavoritesToFile: [self favoritesFile] skipIfEmpty: YES];
        
        if ([managedObjectContext commitEditing])
        {
            if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
            {
				
                // This error handling simply presents error information in a panel with an 
                // "Ok" button, which does not include any attempt at error recovery (meaning, 
                // attempting to fix the error.)  As a result, this implementation will 
                // present the information to the user and then follow up with a panel asking 
                // if the user wishes to "Quit Anyway", without saving the changes.
                
                // Typically, this process should be altered to include application-specific 
                // recovery steps.  
                
                BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
				
                if (errorResult == YES)
                {
                    reply = NSTerminateCancel;
                } 
                else
                {
                    int alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?" , @"Quit anyway", @"Cancel", nil);
                    if (alertReturn == NSAlertAlternateReturn)
                    {
                        reply = NSTerminateCancel;	
                    }
                }
            }
        }
        else
        {
            reply = NSTerminateCancel;
        }
    }
    
    if (reply == NSTerminateCancel)
        return reply;
    
    reply = NSTerminateNow;
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
    
    [[MamePreferences standardPreferences] setGamesSortDescriptors: gameSortDescriptors];
    [[MamePreferences standardPreferences] synchronize];
}

- (void) applicationDidBecomeActive: (NSNotification *) notification;
{
    [mMameView setInputEnabled: YES];
}

- (void) applicationDidResignActive: (NSNotification *) notification;
{
    [mMameView setInputEnabled: NO];
}

- (BOOL)windowShouldClose: (id) sender;
{
    if (sender != mOpenPanel)
        [NSApp terminate: nil];
    return YES;
}

- (void) windowWillClose: (NSNotification *) notification
{
    if ([notification object] == mOpenPanel)
        [NSApp terminate: nil];
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
    {
        mPreferencesController = [[PreferencesWindowController alloc]
            initWithMameController: self];
    }
    
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

- (void) updateEffect;
{
    if (!mVisualEffectEnabled)
    {
        [mMameView setQuartzComposerFile: nil];
        return;
    }
    
    NSString * effectName = [mEffectNames objectAtIndex: mCurrentEffectIndex];
    NSString * effectPath = [mEffectPathsByName objectForKey: effectName];
    if (effectPath != nil)
    {
        if ([[effectPath pathExtension] isEqualToString: @"qtz"])
            [mMameView setQuartzComposerFile: effectPath];
        else
            [mMameView setImageEffect: effectPath];
        return;
    }
    
    [mMameView setQuartzComposerFile: nil];
}

//=========================================================== 
// - visualEffectEnabled
//=========================================================== 
- (BOOL) visualEffectEnabled
{
    return mVisualEffectEnabled;
}

//=========================================================== 
// - setVisualEffectEnabled:
//=========================================================== 
- (void) setVisualEffectEnabled: (BOOL) flag
{
    mVisualEffectEnabled = flag;
    [self updateEffect];
}

- (NSArray *) visualEffectNames;
{
    return mEffectNames;
}

- (int) currentEffectIndex;
{
    return mCurrentEffectIndex;
}

- (void) setCurrentEffectIndex: (int) currentEffectIndex;
{
    if (currentEffectIndex >= [mEffectNames count])
        return;
    
    NSMenuItem * item = [mEffectsMenu itemAtIndex: mCurrentEffectIndex];
    [item setState: NO];

    mCurrentEffectIndex = currentEffectIndex;
    [self updateEffect];
    
    item = [mEffectsMenu itemAtIndex: mCurrentEffectIndex];
    [item setState: YES];
}

- (void) setCurrentVisualEffectName: (NSString *) effectName;
{
    unsigned index = [mEffectNames indexOfObject: effectName];
    if (index != NSNotFound)
    {
        [self setCurrentEffectIndex: index];
        [self setVisualEffectEnabled: YES];
    }
    else
        [self setVisualEffectEnabled: NO];
}

- (IBAction) nextVisualEffect: (id) sender;
{
    int nextEffect = mCurrentEffectIndex + 1;
    if (nextEffect < [mEffectNames count])
        [self setCurrentEffectIndex: nextEffect];
}

- (IBAction) previousVisualEffects: (id) sender;
{
    int nextEffect = mCurrentEffectIndex - 1;
    if (nextEffect >= 0)
        [self setCurrentEffectIndex: nextEffect];
}        

- (IBAction) visualEffectsMenuChanged: (id) sender;
{
    int effectIndex = [mEffectsMenu indexOfItem: sender];
    [self setCurrentEffectIndex: effectIndex];
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
    if ((sender == mGamesTable) &&
        ([mGamesTable clickedRow] == -1))
    {
        return;
    }
    
    NSArray * selectedGames = [mGamesController selectedObjects];
    if ([selectedGames count] != 1)
    {
        JRLogError(@"[selectedGames coount] != 1: %d", [selectedGames count]);
        return;
    }
    GameMO * game = [selectedGames objectAtIndex: 0];
    mGameName = [[game shortName]  retain];
    [game setLastPlayed: [NSDate date]];
    [game setPlayCountValue: [game playCountValue]+1];
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

- (IBAction) toggleThrottled: (id) sender;
{
    [mMameView toggleThrottled];
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

- (IBAction) auditSelectedGames: (id) sender;
{
    NSArray * selectedGames = [self selectedGames];
    [mUpdater auditGames: selectedGames];
    
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

- (IBAction) showWhatsNew: (id) sender;
{
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    NSString * whatsNew = 
        [myBundle pathForResource: @"whatsnew" ofType: @"txt"];
    [[NSWorkspace sharedWorkspace] openFile: whatsNew];
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
    
    // Use NSInvocation to perform the following on the main thread:
    // [self logMessage: message withAttributes: logAttributes];
    
    SEL selector = @selector(logMessage:withAttributes:);
    NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:
        [self methodSignatureForSelector: selector]];
    [invocation setTarget: self];
    [invocation setSelector: selector];
    [invocation setArgument: &message atIndex: 2];
    [invocation setArgument: &logAttributes atIndex: 3];
    [invocation performSelectorOnMainThread: @selector(invoke)
                                 withObject: nil
                              waitUntilDone: YES];
    
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
    [mUpdater pause];
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
            [alert setInformativeText: @"View the Log Window for details."];
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
        if (mQuitOnError)
        {
            [NSApp terminate: nil];
        }
        else
        {
            [[mMameView window] orderOut: self];
            [mGameName release];
            mGameName = nil;
            [mUpdater resume];
            [self chooseGameAndStart];
            /*
             * Only exit full screen, after the MAME window is closed, and the
             * open window is open.  Otherwise, the MAME window may be briefly
             * visible, or theopen window may not be.
             */
            [mMameView setFullScreen: false];
        }
    }
    [self setGameRunning: NO];
}

@end

#pragma mark -

@implementation MameController (Private)

- (void) updatePredicate;
{
    NSMutableArray * terms = [NSMutableArray array];
    NSMutableDictionary * variables = [NSMutableDictionary dictionary];

    // [terms addObject: @"(driverIndex != nil)"];
    if (mGameFilterIndex == 1)
        [terms addObject: @"(auditStatus != nil AND (auditStatus == 0 OR auditStatus == 1))"];
    
    if (mFilterString != nil)
    {
        [terms addObject: @"(shortName contains[c] $FILTER OR longName contains[c] $FILTER)"];
        [variables setObject: mFilterString forKey: @"FILTER"];
    }
    
    if (!mShowClones)
    {
        [terms addObject: @"(parentShortName == NIL)"];
    }
    
    NSString * format = nil;
    if ([terms count] > 0)
        format = [terms componentsJoinedByString: @" AND "];
    JRLogDebug(@"Setting new predicate: %@", format);
    NSPredicate * predicate = [NSPredicate predicateWithFormat: format];
    
    predicate = [predicate predicateWithSubstitutionVariables: variables];
    
    [mGamesController setFilterPredicate: predicate];
}

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

    [self setSyncToRefresh: [preferences syncToRefresh]];
    [self setLinearFilter: [preferences linearFilter]];
    [self setCurrentVisualEffectName: [preferences visualEffect]];

    [mMameView setThrottled: [preferences throttled]];
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
    [mMameView setShouldHideMouseCursor: [preferences grabMouse]];
    
    [preferences copyToMameConfiguration: mConfiguration];
    
    if ([preferences smoothFont])
    {
        NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
        NSArray * fontPath = [NSArray arrayWithObjects:
            [mConfiguration fontPath], [myBundle resourcePath], nil];
        [mConfiguration setFontPath: [fontPath componentsJoinedByString: @";"]];
    }
    [mConfiguration setCheatFile:
        [MameApplicationSupportDirectory() stringByAppendingPathComponent: @"cheat.dat"]];
}

- (void) setGameLoading: (BOOL) gameLoading;
{
    mGameLoading = gameLoading;
#if 0
    if (mGameLoading)
    {
        [mProgressIndicator setIndeterminate: YES];
        [mProgressIndicator startAnimation: self];
    }
    else
    {
        [mProgressIndicator setIndeterminate: YES];
        [mProgressIndicator stopAnimation: self];
    }
#endif
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
- (void) initVisualEffects;
{
    mEffectPathsByName = [[NSMutableDictionary alloc] init];
    
    NSBundle * myBundle = [NSBundle mainBundle];
    NSString * bundleEffects = [[myBundle resourcePath]
        stringByAppendingPathComponent: @"Effects"];
    MamePreferences * preferences = [MamePreferences standardPreferences];
    NSArray * effectPaths = [NSArray arrayWithObjects:
        bundleEffects, [preferences effectPath], nil];
    NSEnumerator * e = [effectPaths objectEnumerator];
    NSString * path;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    while (path = [e nextObject])
    {
        NSArray * paths = [fileManager directoryContentsAtPath: path];
        NSArray * extensions = [NSArray arrayWithObjects: @"png", @"qtz", nil];
        NSArray * effects = [paths pathsMatchingExtensions: extensions];
        NSEnumerator * f = [effects objectEnumerator];
        NSString * effect;
        while (effect = [f nextObject])
        {
            NSString * name = [effect stringByDeletingPathExtension];
            NSString * fullPath = [path stringByAppendingPathComponent: effect];
            [mEffectPathsByName setValue: fullPath forKey: name];
        }
    }
    
    NSArray * names = [mEffectPathsByName allKeys];
    names = [names sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
    mEffectNames = [names retain];
}

- (void) initVisualEffectsMenu;
{
    NSEnumerator * e = [mEffectNames objectEnumerator];
    NSString * name;
    while (name = [e nextObject])
    {
        [mEffectsMenu addItemWithTitle: name
                                action: @selector(visualEffectsMenuChanged:)
                         keyEquivalent: @""];
    }
}

- (void) updateGameFilterMenu;
{
    int count = [mGameFilterMenu numberOfItems];
    int i;
    for (i = 0; i < count; i++)
    {
        NSMenuItem * item = [mGameFilterMenu itemAtIndex: i];
        int state = (mGameFilterIndex == i? NSOnState : NSOffState);
        [item setState: state];
    }
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
#pragma mark Folders

- (NSString *) applicationSupportFolder;
{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"MAME OS X"];
}

- (NSString *) favoritesFile;
{
    NSString * file = [self applicationSupportFolder];
    file = [file stringByAppendingPathComponent: @"Favorites.plist"];
    return file;
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
        const game_driver * matches[5];
        driver_list_get_approx_matches(drivers, [mGameName UTF8String], ARRAY_LENGTH(matches), matches);
        NSMutableString * message = [NSMutableString stringWithString: @"Closest matches:"];
        int drvnum;
        for (drvnum = 0; drvnum < ARRAY_LENGTH(matches); drvnum++)
        {
            if (matches[drvnum] != NULL)
            {
                [message appendFormat: @"\n%s [%s]",
                    matches[drvnum]->name,
                    matches[drvnum]->description];
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

- (void) registerForUrls;
{
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void) getUrl: (NSAppleEventDescriptor *) event
 withReplyEvent: (NSAppleEventDescriptor *) replyEvent;
{
	NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	// now you can create an NSURL and grab the necessary parts
    JRLogInfo(@"Handle URL: %@", urlString);
    NSURL * url = [NSURL URLWithString: urlString];
    mGameName = [[url host] retain];
    mQuitOnError = (mGameName == nil)? NO : YES;
}

#pragma mark -
#pragma mark Favorites

- (GroupMO *) favoritesGroup;
{
    if (mFavoritesGroup == nil)
    {
        mFavoritesGroup = [GroupMO findOrCreateGroupWithName: GroupFavorites
                                                   inContext: [self managedObjectContext]];
        [mFavoritesGroup retain];
    }
    return mFavoritesGroup;
}

- (void) exportFavoritesToFile: (NSString *) file
                   skipIfEmpty: (BOOL) skipIfEmpty;
{
    NSManagedObjectContext * context = [self managedObjectContext];
    GroupMO * favorites = [self favoritesGroup];
    NSMutableSet * members = [favorites membersSet];
    NSArray * favoriteNames = [[members valueForKey: @"shortName"] allObjects];
    BOOL skipWrite = NO;
    if (([favoriteNames count] == 0) && skipIfEmpty)
        skipWrite = YES;
    
    if (!skipWrite)
        [favoriteNames writeToFile: file atomically: YES];
}

- (void) importFavoritesFromFile: (NSString *) file;
{
    NSArray * favoriteNames = [NSArray arrayWithContentsOfFile: file];
    NSManagedObjectContext * context = [self managedObjectContext];
    NSArray * favoriteGames = [GameMO gamesWithShortNames: favoriteNames
                                                inContext: context];
    GroupMO * favorites = [self favoritesGroup];
    NSMutableSet * members = [favorites membersSet];
    [members removeAllObjects];
    [members addObjectsFromArray: favoriteGames];
    [self saveAction: nil];
}

@end

