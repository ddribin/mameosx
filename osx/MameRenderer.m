//
//  MameRenderer.m
//  mameosx
//
//  Created by Dave Dribin on 9/23/06.
//

#import "MameRenderer.h"
#import "MameTextureTable.h"
#import "MameOpenGLTexture.h"

@interface MameRenderer (Private)

- (void) renderFrame : (const render_primitive_list *) primlist;
- (void) renderLine: (render_primitive *) primitive;
- (void) renderQuad: (render_primitive *) primitive;
- (void) renderTexturedQuad: (render_primitive *) primitive
                    texture: (MameOpenGLTexture *) texture;

@end

static void cv_assert(CVReturn cr, NSString * message)
{
    if (cr != kCVReturnSuccess)
        NSLog(@"Core video returned: %d: %@", cr, message);
}

@implementation MameRenderer

- (CVOpenGLTextureRef) currentFrameTexture;
{
    return mCurrentFrameTexture;
}

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat
            width: (float) windowWidth
           height: (float) windowHeight;
{
    mWindowWidth = windowWidth;
    mWindowHeight = windowHeight;
    mTextureTable = [[MameTextureTable alloc] init];
    
    //Create the OpenGL context used to render the composition (a separate OpenGL context from the destination one is needed to render into CoreVideo OpenGL buffers)
    NSOpenGLPixelFormat * glPixelFormat = mameViewFormat;
    mGlContext = [[NSOpenGLContext alloc] initWithFormat:glPixelFormat shareContext:nil];
    [mGlContext makeCurrentContext];
    
    glShadeModel(GL_SMOOTH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    
    glViewport(0.0, 0.0, (GLsizei)mWindowWidth, (GLsizei)mWindowHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, (GLdouble)mWindowWidth, (GLdouble)mWindowHeight, 0.0, 0.0, -1.0);
    
    
    NSMutableDictionary * bufferOptions = [NSMutableDictionary dictionary];
    [bufferOptions setValue:[NSNumber numberWithInt: mWindowWidth]
                     forKey:(NSString*)kCVOpenGLBufferWidth];
    [bufferOptions setValue:[NSNumber numberWithInt: mWindowHeight]
                     forKey:(NSString*)kCVOpenGLBufferHeight];
    if(CVOpenGLBufferPoolCreate(NULL, NULL, (CFDictionaryRef)bufferOptions, &mBufferPool) != kCVReturnSuccess)
    {
        NSLog(@"Could not create buffer pool");
        mBufferPool = NULL;
    }
    if (CVOpenGLBufferCreate(NULL, mWindowWidth, mWindowHeight, (CFDictionaryRef)bufferOptions,
                             &mCurrentFrame))
    {
        NSLog(@"Could not create current frame buffer");
    }
    
    NSOpenGLContext * cacheContext = mameViewContext;
    NSOpenGLPixelFormat * cachePFormat = mameViewFormat;
    cv_assert(CVOpenGLTextureCacheCreate(NULL, 0, (CGLContextObj) [cacheContext CGLContextObj],
                                         (CGLPixelFormatObj) [cachePFormat CGLPixelFormatObj], 0, &mFrameTextureCache),
              @"Could not create frame texture cache");
    
    cv_assert(CVOpenGLTextureCacheCreate(NULL, 0, (CGLContextObj) [mGlContext CGLContextObj],
                                         (CGLPixelFormatObj) [glPixelFormat CGLPixelFormatObj], 0, &mPrimTextureCache),
              @"Could not create primitive texture cache");
}

- (void) updateVideo: (const render_primitive_list *) primlist
{
    [mGlContext makeCurrentContext];
    
    CVOpenGLTextureRelease(mCurrentFrameTexture);
    mCurrentFrameTexture = NULL;
    CVOpenGLTextureCacheFlush(mFrameTextureCache, 0);
    
    // Use the buffer as the OpenGL context destination
    if(CVOpenGLBufferAttach(mCurrentFrame, (CGLContextObj) [mGlContext CGLContextObj], 0, 0, 0) == kCVReturnSuccess)
    {
        [self renderFrame: primlist];
        glFlush();
        CVOpenGLTextureCacheCreateTextureFromImage(NULL, mFrameTextureCache,
                                                   mCurrentFrame,
                                                   0, &mCurrentFrameTexture);
    }
}

- (void) renderFrame : (const render_primitive_list *) primlist
{
    // clear the screen and Z-buffer
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // reset the current matrix to the identity
    glLoadIdentity();                                  
    
    // we're doing nothing 3d, so the Z-buffer is currently not interesting
    glDisable(GL_DEPTH_TEST);
    
    glDisable(GL_LINE_SMOOTH);
    glDisable(GL_POINT_SMOOTH);
    
    // enable blending
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    // set lines and points just barely above normal size to get proper results
    glLineWidth(1.1f);
    glPointSize(1.1f);
    
    // set up a nice simple 2D coordinate system, so GL behaves exactly how we'd like.
    //
    // (0,0)     (w,0)
    //   |~~~~~~~~~|
    //   |         |
    //   |         |
    //   |         |
    //   |_________|
    // (0,h)     (w,h)
    
    glViewport(0.0, 0.0, (GLsizei)mWindowWidth, (GLsizei)mWindowHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, (GLdouble)mWindowWidth, (GLdouble)mWindowHeight, 0.0, 0.0, -1.0);
    
    // compute centering parameters
    mCenteringOffset = NSMakeSize(0.0f, 0.0f);
    
    // first update/upload the textures
    CVOpenGLTextureCacheFlush(mPrimTextureCache, 0);
    
    render_primitive * prim;
    for (prim = primlist->head; prim != NULL; prim = prim->next)
    {
        if (prim->texture.base != NULL)
        {
            [mTextureTable update: prim textureCache: mPrimTextureCache];
        }
    }
    
    // now draw
    for (prim = primlist->head; prim != NULL; prim = prim->next)
    {
        switch (prim->type)
        {
            case RENDER_PRIMITIVE_LINE:
                [self renderLine: prim];
                break;
                
            case RENDER_PRIMITIVE_QUAD:
            {
                MameOpenGLTexture * texture = [mTextureTable findTextureForPrimitive: prim];
                if (texture == nil)
                    [self renderQuad: prim];
                else
                    [self renderTexturedQuad: prim texture: texture];
            }
                break;
        }
    }
}

INLINE void set_blendmode(int blendmode)
{
    switch (blendmode)
    {
        case BLENDMODE_NONE:
            glDisable(GL_BLEND);
            break;
        case BLENDMODE_ALPHA:       
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            break;
        case BLENDMODE_RGB_MULTIPLY:    
            glEnable(GL_BLEND);
            glBlendFunc(GL_DST_COLOR, GL_ZERO);
            break;
        case BLENDMODE_ADD:     
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE);
            break;
    }
}

- (void) renderLine: (render_primitive *) prim;
{
    set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
    
    // check if it's really a point
    if (((prim->bounds.x1 - prim->bounds.x0) == 0) &&
        ((prim->bounds.y1 - prim->bounds.y0) == 0))
    {
        glBegin(GL_POINTS);
        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
        glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
                   prim->bounds.y0 + mCenteringOffset.height);
        glEnd();
    }
    else
    {
        glBegin(GL_LINES);
        glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
        glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
                   prim->bounds.y0 + mCenteringOffset.height);
        glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
                   prim->bounds.y1 + mCenteringOffset.height);
        glEnd();
    }
}

- (void) renderQuad: (render_primitive *) prim;
{
    set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
    glBegin(GL_QUADS);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g,
              prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glEnd();
}

- (void) renderTexturedQuad: (render_primitive *) prim 
                    texture: (MameOpenGLTexture *) texture;
{
    float du = texture->ustop - texture->ustart; 
    float dv = texture->vstop - texture->vstart;
    
    set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
    
    GLenum textureTarget = CVOpenGLTextureGetTarget(texture->cv_texture);
    glEnable(textureTarget);
    glBindTexture(CVOpenGLTextureGetTarget(texture->cv_texture),
                  CVOpenGLTextureGetName(texture->cv_texture));
    
    // non-screen textures will never be filtered
    glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    
    // texture rectangles can't wrap
    glTexParameteri(textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP);
    
    // texture coordinates for TEXTURE_RECTANGLE are 0,0 -> w,h
    // rather than 0,0 -> 1,1 as with normal OpenGL texturing
    du *= (float) texture->rawwidth;
    dv *= (float) texture->rawheight;
    
    glBegin(GL_QUADS);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.tl.u,
                 texture->vstart + dv * prim->texcoords.tl.v);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.tr.u,
                 texture->vstart + dv * prim->texcoords.tr.v);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y0 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.br.u,
                 texture->vstart + dv * prim->texcoords.br.v);
    glVertex2f(prim->bounds.x1 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glColor4f(prim->color.r, prim->color.g, prim->color.b, prim->color.a);
    glTexCoord2f(texture->ustart + du * prim->texcoords.bl.u,
                 texture->vstart + dv * prim->texcoords.bl.v);
    glVertex2f(prim->bounds.x0 + mCenteringOffset.width,
               prim->bounds.y1 + mCenteringOffset.height);
    glEnd();
    glDisable(textureTarget);
}

@end
