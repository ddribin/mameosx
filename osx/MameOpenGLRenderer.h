//
//  MameOpenGLRenderer.h
//  mameosx
//
//  Created by Dave Dribin on 9/25/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include "render.h"

@class MameTextureTable;

@interface MameOpenGLRenderer : NSObject
{
    MameTextureTable * mTextureTable;
    int32_t mWindowWidth;
    int32_t mWindowHeight;
    NSSize mCenteringOffset;
    
    NSOpenGLContext * mGlContext;
}

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat
            width: (float) windowWidth
           height: (float) windowHeight;

- (void) renderFrame : (const render_primitive_list *) primlist;

@end
