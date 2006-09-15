//
//  MameView.h
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import <Cocoa/Cocoa.h>

@class MameController;

@interface MameView : NSOpenGLView
{
    IBOutlet MameController * mController;
    CIContext * mCiContext;
}

- (void) createCIContext;
- (CIContext *) ciContext;

@end
