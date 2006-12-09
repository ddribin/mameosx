//
//  AudioEffectWindowController.m
//  mameosx
//
//  Created by Dave Dribin on 12/9/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "AudioEffectWindowController.h"
#import "MameView.h"

@interface AudioEffectWindowController (Private)

- (void) setAudioUnitView: (NSView *) view;

@end

@implementation AudioEffectWindowController

- (id) initWithMameView: (MameView *) mameView;
{
    self = [super initWithWindowNibName: @"AudioEffects"];
    if (self == nil)
        return nil;
    
    mMameView = [mameView retain];
    mAudioUnitView = nil;
    
    return self;
}

- (void)updateCpuLoad:(NSTimer*)theTimer
{
    [self willChangeValueForKey: @"cpuLoad"];
    mCpuLoad = [mMameView audioCpuLoad] * 100.0;
    [self didChangeValueForKey: @"cpuLoad"];
}

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object 
                         change: (NSDictionary *) change
                        context: (void *) context;
{
    if ((object == mMameView) && [keyPath isEqualToString: @"audioEffectEnabled"])
    {
        NSView * view = [mMameView createAudioEffectViewWithSize: NSMakeSize(400, 300)];
        [self setAudioUnitView: view];
    }
}

- (void) awakeFromNib;
{
    NSView * view = [mMameView createAudioEffectViewWithSize: NSMakeSize(400, 300)];
    [self setAudioUnitView: view];
    
    [mMameView addObserver: self
                forKeyPath: @"audioEffectEnabled"
                   options: (NSKeyValueObservingOptionNew |
                             NSKeyValueObservingOptionOld)
                   context: nil];
}

- (MameView *) mameView;
{
    return mMameView;
}

- (float) cpuLoad;
{
    return mCpuLoad;
}

- (IBAction) showWindow: (id) sender;
{
    [super showWindow: sender];
    
    [self updateCpuLoad: nil];
    if (mCpuLoadTimer == nil)
    {
        mCpuLoadTimer =
            [NSTimer scheduledTimerWithTimeInterval: 1.0
                                             target: self
                                           selector: @selector(updateCpuLoad:)
                                           userInfo: nil
                                            repeats: YES];
        [mCpuLoadTimer retain];
    }
}

- (void) windowWillClose: (NSNotification *) notification;
{
    if (mCpuLoadTimer != nil)
    {
        [mCpuLoadTimer invalidate];
        [mCpuLoadTimer release];
        mCpuLoadTimer = nil;
    }
}

@end

@implementation AudioEffectWindowController (Private)

- (void)myTimerFireMethod:(NSTimer*)theTimer
{
    [mContainerView addSubview: mAudioUnitView];
}


- (void) auViewDidChange: (NSNotification *) notification
{
    NSWindow * window = [self window];
    NSSize auSize = [mAudioUnitView bounds].size;
    NSSize containerSize = [mContainerView bounds].size;
    if (!NSEqualSizes(auSize, containerSize))
    {
        float deltaWidth = containerSize.width - auSize.width;
        float deltaHeight = containerSize.height - auSize.height;
        
        NSRect windowFrame = [window frame];
        windowFrame.size.width -= deltaWidth;
        windowFrame.size.height -= deltaHeight;
        windowFrame.origin.y += deltaHeight;
        [window setFrame: windowFrame display: YES];
    }
}

- (void) setAudioUnitView: (NSView *) view;
{
    if (mAudioUnitView != nil)
    {
        [mAudioUnitView removeFromSuperview];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: nil
                                                      object: mAudioUnitView];
        [mAudioUnitView release];
        mAudioUnitView == nil;
    }
    
    if (view == nil)
    {
        view = [mNoEffectView retain];
    }
    
    mAudioUnitView = [view retain];
    NSWindow * window = [self window];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(auViewDidChange:)
                                                 name: nil
                                               object: mAudioUnitView];
    NSSize auSize = [mAudioUnitView bounds].size;
    NSSize containerSize = [mContainerView bounds].size;
    
    float deltaWidth = containerSize.width - auSize.width;
    float deltaHeight = containerSize.height - auSize.height;
    
    NSRect oldFrameRect = [window frame];
    NSRect newFrameRect = oldFrameRect;
    newFrameRect.size.width -= deltaWidth;
    newFrameRect.size.height -= deltaHeight;
    newFrameRect.origin.y += deltaHeight;

    unsigned mask = [mAudioUnitView autoresizingMask];
    BOOL widthSizable = ((mask & NSViewWidthSizable) != 0);
    BOOL heightSizable = ((mask & NSViewHeightSizable) != 0);
    NSSize minSize;
    NSSize maxSize;
    if (widthSizable)
    {
        minSize.width = newFrameRect.size.width;
        maxSize.width = FLT_MAX;
    }
    else if (!widthSizable)
    {
        minSize.width = newFrameRect.size.width;
        maxSize.width = newFrameRect.size.width;
    }
    
    if (heightSizable)
    {
        minSize.height = newFrameRect.size.height;
        maxSize.height = FLT_MAX;
    }
    else if (!heightSizable)
    {
        minSize.height = newFrameRect.size.height;
        maxSize.height = newFrameRect.size.height;
    }
    [window setMinSize: minSize];
    [window setMaxSize: maxSize];
    if (!heightSizable && !widthSizable)
    {
        [window setShowsResizeIndicator: NO];
    }
    else
    {
        [window setShowsResizeIndicator: YES];
    }
	
    BOOL animate = !NSEqualRects(oldFrameRect, newFrameRect);
    if (animate)
    {
        NSTimeInterval resizeTime = [window animationResizeTime: newFrameRect];
        [NSTimer scheduledTimerWithTimeInterval: resizeTime
                                         target: self
                                       selector: @selector(myTimerFireMethod:)
                                       userInfo: nil
                                        repeats: NO];
        
        [window setFrame: newFrameRect display: YES animate: YES];
    }
    else
    {
        [window setFrame: newFrameRect display: YES animate: NO];
        [mContainerView addSubview: mAudioUnitView];
    }
}

@end
