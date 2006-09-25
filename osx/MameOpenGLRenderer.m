//
//  MameOpenGLRenderer.m
//  mameosx
//
//  Created by Dave Dribin on 9/25/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MameOpenGLRenderer.h"
#import "MameTextureTable.h"
#import "MameOpenGLTexture.h"

@interface MameOpenGLRenderer (Private)

- (void) renderLine: (render_primitive *) primitive;
- (void) renderQuad: (render_primitive *) primitive;

@end

static void cv_assert(CVReturn cr, NSString * message)
{
    if (cr != kCVReturnSuccess)
        NSLog(@"Core video returned: %d: %@", cr, message);
}

@implementation MameOpenGLRenderer

- (void) osd_init: (NSOpenGLContext *) mameViewContext
           format: (NSOpenGLPixelFormat *) mameViewFormat
            width: (float) windowWidth
           height: (float) windowHeight;
{
    mWindowWidth = windowWidth;
    mWindowHeight = windowHeight;
    mTextureTable = [[MameTextureTable alloc] init];
        
    NSOpenGLPixelFormat * glPixelFormat = mameViewFormat;
    mGlContext = [mameViewContext retain];
   
    cv_assert(CVOpenGLTextureCacheCreate(NULL, 0, (CGLContextObj) [mGlContext CGLContextObj],
                                         (CGLPixelFormatObj) [glPixelFormat CGLPixelFormatObj], 0, &mPrimTextureCache),
              @"Could not create primitive texture cache");
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
        set_blendmode(PRIMFLAG_GET_BLENDMODE(prim->flags));
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
                {
                    [texture renderPrimitive: prim
                             centeringOffset: mCenteringOffset];
                }
            }
                break;
        }
    }
}

@end

@implementation MameOpenGLRenderer (Private)

- (void) renderLine: (render_primitive *) prim;
{    
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

@end
