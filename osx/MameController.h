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
@class MameRenderer;
@class MameInputController;
@class MameAudioController;
@class MameTimingController;
@class MameFileManager;
@class MameConfiguration;

@interface MameController : NSObject
{
    IBOutlet MameView * mMameView;
    IBOutlet NSPopUpButton * mFilterButton;
    IBOutlet NSDrawer * mDrawer;
    IBOutlet NSWindow * mOpenPanel;
    IBOutlet NSComboBox * mGameTextField;
    IBOutlet NSProgressIndicator * mGameLoading;

    MameConfiguration * mConfiguration;

    BOOL mMameIsRunning;
    
    BOOL mIsFiltered;
    NSMutableArray * mFilters;
    CIFilter * mCurrentFilter;
    float inputCenterX;
    float inputCenterY;
    BOOL mMoveInputCenter;
    NSMutableArray * mPreviousGames;
}

- (BOOL) isFiltered;
- (void) setIsFiltered: (BOOL) flag;

- (BOOL) throttled;
- (void) setThrottled: (BOOL) flag;

- (BOOL) syncToRefresh;
- (void) setSyncToRefresh: (BOOL) flag;

- (BOOL) fullScreen;
- (void) setFullScreen: (BOOL) fullScreen;

- (NSArray *) previousGames;

- (IBAction) filterChanged: (id) sender;
- (IBAction) togglePause: (id) sender;
- (IBAction) nullAction: (id) sender;
- (IBAction) raiseOpenPanel: (id) sender;
- (IBAction) endOpenPanel: (id) sender;
- (IBAction) hideOpenPanel: (id) sender;
- (IBAction) setActualSize: (id) sender;
- (IBAction) setDoubleSize: (id) sender;

@end
