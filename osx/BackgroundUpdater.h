//
//  BackgroundUpdater.h
//  mameosx
//
//  Created by Dave Dribin on 7/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MameController;
@class GameMO;

@interface BackgroundUpdater : NSObject
{
    int mPass;
    unsigned mCurrentGameIndex;
    NSMutableArray * mShortNames;
    GameMO * mCurrentGame;
    NSString * mCurrentShortName;
    NSEnumerator * mGameEnumerator;
    
    // Weak references
    MameController * mController;
}

- (id) initWithMameController: (MameController *) controller;

- (void) start;

@end
