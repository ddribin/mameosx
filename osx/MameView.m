//
//  MameView.m
//  mameosx
//
//  Created by Dave Dribin on 8/29/06.
//

#import "MameView.h"
#import "MameController.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

@implementation MameView

- (void) prepareOpenGL;
{
    glShadeModel(GL_SMOOTH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
}

- (void) createCIContext;
{
    [[self openGLContext] makeCurrentContext];
    /* Create CGColorSpaceRef */
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    /* Create CIContext */
    mCiContext = [[CIContext contextWithCGLContext:
        (CGLContextObj)[[self openGLContext] CGLContextObj]
                                       pixelFormat:(CGLPixelFormatObj)
        [[self pixelFormat] CGLPixelFormatObj]
                                           options:[NSDictionary dictionaryWithObjectsAndKeys:
                                               (id)colorSpace,kCIContextOutputColorSpace,
                                               (id)colorSpace,kCIContextWorkingColorSpace,nil]] retain];
    CGColorSpaceRelease(colorSpace);
}

- (CIContext *) ciContext;
{
    return mCiContext;
}

- (BOOL) acceptsFirstResponder
{
    return YES;
}

- (void) keyDown: (NSEvent *) event
{
    [NSCursor setHiddenUntilMouseMoves: YES];
}

//  adjust the viewport
- (void)reshape
{ 
	GLfloat minX, minY, maxX, maxY;
    
    NSRect sceneBounds = [self bounds];
 	NSRect frame = [self frame];
	
    minX = NSMinX(sceneBounds);
	minY = NSMinY(sceneBounds);
	maxX = NSMaxX(sceneBounds);
	maxY = NSMaxY(sceneBounds);
    
    // for best results when using Core Image to render into an OpenGL context follow these guidelines:
    // * ensure that the a single unit in the coordinate space of the OpenGL context represents a single pixel in the output device
    // * the Core Image coordinate space has the origin in the bottom left corner of the screen -- you should configure the OpenGL
    //   context in the same way
    // * the OpenGL context blending state is respected by Core Image -- if the image you want to render contains translucent pixels,
    //   itÕs best to enable blending using a blend function with the parameters GL_ONE, GL_ONE_MINUS_SRC_ALPHA
    
    // some typical initialization code for a view with width W and height H
    
    glViewport(0, 0, (GLsizei)frame.size.width, (GLsizei)(frame.size.height));	// set the viewport
    
    glMatrixMode(GL_MODELVIEW);    // select the modelview matrix
    glLoadIdentity();              // reset it

    glMatrixMode(GL_PROJECTION);   // select the projection matrix
    glLoadIdentity();              // reset it
    
#if 1
    gluOrtho2D(minX, maxX, minY, maxY);	// define a 2-D orthographic projection matrix
#endif
    
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
}



#if 0
- (void) reshape
{
	NSOpenGLContext *currentContext = nil;
	NSRect bounds = NSZeroRect;
	
	currentContext = [self openGLContext];
	bounds = [self bounds];

	// [self Lock];
	{
        float x = bounds.origin.x;
        float y = bounds.origin.y;
        float w = bounds.size.width;
        float h = bounds.size.height;
		[currentContext makeCurrentContext];
        glViewport(x, y, w, h);
        
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, w, 0, h, 0, 1);
        
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
	}
	// [self Unlock];
	
	[self setNeedsDisplay:YES];
}
#endif

@end
