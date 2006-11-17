/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>

#import <QuartzCore/QuartzCore.h>
#include "render.h"

@class MameOpenGLTexture;

@interface MameTextureTable : NSObject
{
    CVOpenGLTextureCacheRef mTextureCache;
    NSMutableArray * mTextures;
}

- (id) initWithContext: (NSOpenGLContext *) context
           pixelFormat: (NSOpenGLPixelFormat *) pixelFormat;

- (MameOpenGLTexture *) findTextureForPrimitive: (const render_primitive *) primitive;

- (MameOpenGLTexture *) findOrCreateTextureForPrimitive: (const render_primitive *) primitive;

- (void) updateTextureForPrimitive: (const render_primitive *) primitive;

- (void) performHousekeeping;


@end
