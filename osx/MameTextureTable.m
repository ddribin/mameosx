//
//  MameTextureTable.m
//  mameosx
//
//  Created by Dave Dribin on 9/22/06.
//

#import "MameTextureTable.h"
#import "MameOpenGLTexture.h"


@implementation MameTextureTable

- (id) init
{
    if ([super init] == nil)
        return nil;
    
    mTextures = [[NSMutableArray alloc] init];
   
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mTextures release];
    
    mTextures = nil;
    [super dealloc];
}

+ (UINT32) computeHashForPrimitive: (const render_primitive *) primitive;
{
    const render_texinfo * texinfo = &primitive->texture;
    UINT32 flags = primitive->flags;
    return (UINT32)texinfo->base ^ (flags & (PRIMFLAG_BLENDMODE_MASK | PRIMFLAG_TEXFORMAT_MASK));
}

- (MameOpenGLTexture *) findTextureForPrimitive: (const render_primitive *) primitive;
{
    MameOpenGLTexture * texture;
    NSEnumerator * i = [mTextures objectEnumerator];
    while (texture = [i nextObject])
    {
        if ([texture isEqualToPrimitive: primitive])
            return texture;
    }
    return nil;
}

- (MameOpenGLTexture *) findOrCreateTextureForPrimitive: (const render_primitive *) primitive
                                           textureCache: (CVOpenGLTextureCacheRef) textureCache;
{
    MameOpenGLTexture * texture = [self findTextureForPrimitive: primitive];
    if (texture == nil)
    {
        texture = [[MameOpenGLTexture alloc] initWithPrimitive: primitive
                                                  textureCache: textureCache];
        [texture autorelease];
        [mTextures addObject: texture];
    }
    return texture;
}


- (void) update: (const render_primitive *) primitive
   textureCache: (CVOpenGLTextureCacheRef) textureCache;
{
    MameOpenGLTexture * texture = [self findOrCreateTextureForPrimitive: primitive
                                                           textureCache: textureCache];
    if ([texture sequenceId] != primitive->texture.seqid)
    {
        [texture updateData: primitive textureCache: textureCache];
    }
}

@end
