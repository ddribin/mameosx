//
//  MameTextureTable.m
//  mameosx
//
//  Created by Dave Dribin on 9/22/06.
//

#import "MameTextureTable.h"
#import "MameOpenGLTexture.h"


@implementation MameTextureTable

- (id) initWithContext: (NSOpenGLContext *) context
           pixelFormat: (NSOpenGLPixelFormat *) pixelFormat;
{
    if ([super init] == nil)
        return nil;
    
    CVReturn rc =
        CVOpenGLTextureCacheCreate(NULL, 0, (CGLContextObj) [context CGLContextObj],
                                   (CGLPixelFormatObj) [pixelFormat CGLPixelFormatObj],
                                   0, &mTextureCache);
    if (rc != kCVReturnSuccess)
        return nil;

    mTextures = [[NSMutableArray alloc] init];
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    CVOpenGLTextureCacheRelease(mTextureCache);
    [mTextures release];
    
    mTextures = nil;
    [super dealloc];
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

- (MameOpenGLTexture *) findOrCreateTextureForPrimitive: (const render_primitive *) primitive;
{
    MameOpenGLTexture * texture = [self findTextureForPrimitive: primitive];
    if (texture == nil)
    {
        texture = [[MameOpenGLTexture alloc] initWithPrimitive: primitive
                                                  textureCache: mTextureCache];
        [texture autorelease];
        [mTextures addObject: texture];
    }
    return texture;
}


- (void) updateTextureForPrimitive: (const render_primitive *) primitive;
{
    MameOpenGLTexture * texture = [self findOrCreateTextureForPrimitive: primitive];
    if ([texture sequenceId] != primitive->texture.seqid)
    {
        [texture updateData: primitive textureCache: mTextureCache];
    }
}

- (void) performHousekeeping;
{
    CVOpenGLTextureCacheFlush(mTextureCache, 0);
}

@end
