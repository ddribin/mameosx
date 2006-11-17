/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include "render.h"

@class MameTextureTable;

@interface MameOpenGLRenderer : NSObject
{
    MameTextureTable * mTextureTable;
    NSSize mCenteringOffset;
    
    NSOpenGLContext * mGlContext;
}

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat;

- (void) renderFrame : (const render_primitive_list *) primlist
             withSize: (NSSize) size;

@end
