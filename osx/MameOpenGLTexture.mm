//
//  MameOpenGLTexture.m
//  mameosx
//
//  Created by Dave Dribin on 9/22/06.
//

#import "MameOpenGLTexture.h"
#import "MameTextureConverter.h"

@interface MameOpenGLTexture (Private)

@end

static void cv_assert(CVReturn cr, NSString * message)
{
    if (cr != kCVReturnSuccess)
        NSLog(@"Core video returned: %d: %@", cr, message);
}

@implementation MameOpenGLTexture

+ (UINT32) computeHashForPrimitive: (const render_primitive *) primitive;
{
    const render_texinfo * texinfo = &primitive->texture;
    UINT32 flags = primitive->flags;
    return (UINT32)texinfo->base ^ (flags & (PRIMFLAG_BLENDMODE_MASK | PRIMFLAG_TEXFORMAT_MASK));
}

- (id) initWithPrimitive: (const render_primitive *) primitive
            textureCache: (CVOpenGLTextureCacheRef) textureCache;
{
    if ([super init] == nil)
        return nil;
    
    hash = [MameOpenGLTexture computeHashForPrimitive: primitive];
    flags = primitive->flags;
    texinfo = primitive->texture;
    xprescale = 1;
    yprescale = 1;
    
    mPixelBuffer = NULL;
    mCVTexture = NULL;
    
    [self computeSize];
    [self setData: textureCache];
   
    return self;
}

- (BOOL) isEqualToPrimitive: (const render_primitive *) primitive;
{
    UINT32 primitiveHash = [MameOpenGLTexture computeHashForPrimitive: primitive];
    if ((hash == primitiveHash) &&
        (texinfo.base == primitive->texture.base) &&
        (texinfo.width == primitive->texture.width) &&
        (texinfo.height == primitive->texture.height) &&
        (((flags ^ primitive->flags) & (PRIMFLAG_BLENDMODE_MASK | PRIMFLAG_TEXFORMAT_MASK)) == 0))
    {
        return YES;
    }
    return NO;
}

- (UINT32) sequenceId;
{
    return texinfo.seqid;
}

- (void) computeSize;
{
    UINT32 texwidth = texinfo.width;
    UINT32 texheight = texinfo.height;

    int finalheight = texheight;
    int finalwidth = texwidth;
    
    // if we're above the max width/height, do what?
    if (finalwidth > 2048 || finalheight > 2048)
    {
        static int printed = FALSE;
        if (!printed) fprintf(stderr, "Texture too big! (wanted: %dx%d, max is %dx%d)\n", finalwidth, finalheight, 2048, 2048);
        printed = TRUE;
    }
    
    // compute the U/V scale factors
    ustart = 0.0f;
    ustop = (float)texwidth / (float)finalwidth;
    vstart = 0.0f;
    vstop = (float)texheight / (float)finalheight;
    
    // set the final values
    rawwidth = finalwidth;
    rawheight = finalheight;
}

- (void) setData: (CVOpenGLTextureCacheRef) textureCache;
{
    const render_texinfo * texsource = &texinfo;
    UINT32 *dst32, *dbuf;
    int x, y;

    if (mPixelBuffer == NULL)
    {
        cv_assert(CVPixelBufferCreate(NULL, rawwidth,
                                      rawheight,
                                      PixelBuffer::kPixelFormat,
                                      NULL, &mPixelBuffer),
                  @"Could not create pixle buffer");
    }
    
    int texformat = PRIMFLAG_GET_TEXFORMAT(flags);
    
    cv_assert(CVPixelBufferLockBaseAddress(mPixelBuffer, 0),
              @"Could not lock pixel buffer");
    
    PixelBuffer pixelBuffer(CVPixelBufferGetBaseAddress(mPixelBuffer),
                            CVPixelBufferGetBytesPerRow(mPixelBuffer));
    
    if (texformat == TEXFORMAT_ARGB32)
    {
        MameARGB32Texture cppTexture(texsource);
        convertTexture(cppTexture, pixelBuffer);
    }
    else if (texformat == TEXFORMAT_PALETTE16)
    {
        MamePalette16Texture cppTexture(texsource);
        convertTexture(cppTexture, pixelBuffer);
    }
    else if (texformat == TEXFORMAT_RGB15)
    {
        static bool loggedRGB15 = NO;
        if (!loggedRGB15)
        {
            NSLog(@"TEXFORMAT_RGB15 not yet supported");
            loggedRGB15 = YES;
        }
    }
    else if (texformat == TEXFORMAT_RGB32)
    {
        if (texsource->palette != NULL)
        {
            MamePaletteRGB32Texture cppTexture(texsource);
            convertTexture(cppTexture, pixelBuffer);
        }
        else
        {
            MameRGB32Texture cppTexture(texsource);
            convertTexture(cppTexture, pixelBuffer);
        }
    }
#if 0
    case TEXFORMAT_RGB15:
        src16 = (UINT16 *)texsource->base + y * texsource->rowpixels;
        if (texsource->palette != NULL)
        {
            for (x = 0; x < texsource->width; x++)
            {
                UINT16 pix = *src16++;
                
                *dst32++ = 0xff | texsource->palette[0x40 + ((pix >> 10) & 0x1f)]>>8 | texsource->palette[0x20 + ((pix >> 5) & 0x1f)]<<8 | texsource->palette[0x00 + ((pix >> 0) & 0x1f)]<<24;
            }
        }
            else
            {
                for (x = 0; x < texsource->width; x++)
                {
                    UINT32 pix = (UINT32)*src16++;        
                    
                    *dst32++ = ((pix & 0x7c00) << 1) | ((pix & 0x03e0) << 14) | ((pix & 0x001f) << 27) | 0xff; 
                }
            }
            break;                             
        
    case TEXFORMAT_RGB32:
        src32 = (UINT32 *)texsource->base + y * texsource->rowpixels;
        if (texsource->palette != NULL)
        {
            for (x = 0; x < texsource->width; x++)
            {
                UINT32 srcpix = *src32++;
                *dst32++ = 0xff | 
                    (texsource->palette[0x200 + RGB_RED(srcpix)])>>8 | 
                    (texsource->palette[0x100 + RGB_GREEN(srcpix)])<<8 | 
                    texsource->palette[RGB_BLUE(srcpix)]<<24;
            }
        }
            else
            {
                for (x = 0; x < texsource->width; x++)
                {
                    *dst32++ = (*src32&0x00ff0000) >> 8 |
                    (*src32&0x0000ff00) << 8 |
                    (*src32&0x000000ff) <<24 | 0xff;
                    src32++;
                }
            }
            break;
#endif
    else
    {
        NSLog(@"Unknown texture blendmode=%d format=%d\n", PRIMFLAG_GET_BLENDMODE(flags), 
              PRIMFLAG_GET_TEXFORMAT(flags));
        return;
    }

    cv_assert(CVPixelBufferUnlockBaseAddress(mPixelBuffer, 0),
              @"Could not unlock pixel buffer");
    cv_assert(CVOpenGLTextureCacheCreateTextureFromImage(NULL, textureCache, mPixelBuffer,
                                                         NULL, &mCVTexture),
              @"Could not create primitive texture");
}

- (void) updateData: (const render_primitive *) primitive
       textureCache: (CVOpenGLTextureCacheRef) textureCache;
{
    if (mPixelBuffer != NULL)
    {
        CVPixelBufferRelease(mPixelBuffer);
        CVOpenGLTextureRelease(mCVTexture);
        mPixelBuffer = NULL;
        mCVTexture = NULL;
    }

    flags = primitive->flags;
    texinfo.seqid = primitive->texture.seqid;
    [self setData: textureCache];
}

- (void) renderPrimitive: (const render_primitive * ) primitive
         centeringOffset: (NSSize) mCenteringOffset;
{
    MameOpenGLTexture * texture = self;
    
    float du = ustop - ustart; 
    float dv = vstop - vstart;
    
    GLenum textureTarget = CVOpenGLTextureGetTarget(mCVTexture);
    glEnable(textureTarget);
    glBindTexture(CVOpenGLTextureGetTarget(mCVTexture),
                  CVOpenGLTextureGetName(mCVTexture));
    
    // non-screen textures will never be filtered
    glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    
    // texture rectangles can't wrap
    glTexParameteri(textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP);
    
    // texture coordinates for TEXTURE_RECTANGLE are 0,0 -> w,h
    // rather than 0,0 -> 1,1 as with normal OpenGL texturing
    du *= (float) rawwidth;
    dv *= (float) rawheight;
    
    GLfloat color[4];
    color[0] = primitive->color.r;
    color[1] = primitive->color.g;
    color[2] = primitive->color.b;
    color[3] = primitive->color.a;
    
    glBegin(GL_QUADS);
    glColor4fv(color);
    glTexCoord2f(ustart + du * primitive->texcoords.tl.u,
                 vstart + dv * primitive->texcoords.tl.v);
    glVertex2f(primitive->bounds.x0 + mCenteringOffset.width,
               primitive->bounds.y0 + mCenteringOffset.height);
    glColor4fv(color);
    glTexCoord2f(ustart + du * primitive->texcoords.tr.u,
                 vstart + dv * primitive->texcoords.tr.v);
    glVertex2f(primitive->bounds.x1 + mCenteringOffset.width,
               primitive->bounds.y0 + mCenteringOffset.height);
    glColor4fv(color);
    glTexCoord2f(ustart + du * primitive->texcoords.br.u,
                 vstart + dv * primitive->texcoords.br.v);
    glVertex2f(primitive->bounds.x1 + mCenteringOffset.width,
               primitive->bounds.y1 + mCenteringOffset.height);
    glColor4fv(color);
    glTexCoord2f(ustart + du * primitive->texcoords.bl.u,
                 vstart + dv * primitive->texcoords.bl.v);
    glVertex2f(primitive->bounds.x0 + mCenteringOffset.width,
               primitive->bounds.y1 + mCenteringOffset.height);
    glEnd();
    glDisable(textureTarget);
}

@end

@implementation MameOpenGLTexture (Private)


@end
