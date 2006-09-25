//
//  MameTextureTable.h
//  mameosx
//
//  Created by Dave Dribin on 9/22/06.
//

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
