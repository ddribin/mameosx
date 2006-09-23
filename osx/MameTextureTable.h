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
    NSMutableArray * mTextures;
}

+ (UINT32) computeHashForPrimitive: (const render_primitive *) primitive;

- (MameOpenGLTexture *) findTextureForPrimitive: (const render_primitive *) primitive;

- (MameOpenGLTexture *) findOrCreateTextureForPrimitive: (const render_primitive *) primitive
                                           textureCache: (CVOpenGLTextureCacheRef) textureCache;

- (void) update: (const render_primitive *) primitive
   textureCache: (CVOpenGLTextureCacheRef) textureCache;


@end
