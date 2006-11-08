//
//  MameController.h
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#if defined(__cplusplus)
extern "C" {
#endif
    
#include "osdepend.h"
#include "render.h"

#if defined(__cplusplus)
}
#endif

@class MameView;
@class MameConfiguration;
@class MameFilter;

@interface MameController : NSObject
{
    IBOutlet MameView * mMameView;
    IBOutlet NSPopUpButton * mFilterButton;
    IBOutlet NSDrawer * mDrawer;
    IBOutlet NSWindow * mOpenPanel;
    IBOutlet NSComboBox * mGameTextField;

    MameConfiguration * mConfiguration;

    BOOL mMameIsRunning;
    
    BOOL mIsFiltered;
    NSMutableArray * mFilters;
    MameFilter * mCurrentFilter;
    NSMutableArray * mPreviousGames;
    BOOL mGameLoading;
}

- (BOOL) isFiltered;
- (void) setIsFiltered: (BOOL) flag;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) fullScreen;
- (void) setFullScreen: (BOOL) fullScreen;

- (BOOL) isGameLoading;

- (NSArray *) previousGames;

- (IBAction) filterChanged: (id) sender;
- (IBAction) togglePause: (id) sender;
- (IBAction) nullAction: (id) sender;
- (IBAction) raiseOpenPanel: (id) sender;
- (IBAction) endOpenPanel: (id) sender;
- (IBAction) cancelOpenPanel: (id) sender;
- (IBAction) hideOpenPanel: (id) sender;
- (IBAction) setActualSize: (id) sender;
- (IBAction) setDoubleSize: (id) sender;

@end
