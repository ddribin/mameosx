//
//  MameOpenGLTexture.h
//  mameosx
//
//  Created by Dave Dribin on 9/22/06.
//  Copyright 2006 Bit Maki, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#if defined(__cplusplus)
extern "C" {
#endif

#include "render.h"
    
#if defined(__cplusplus)
}
#endif

#import <QuartzCore/QuartzCore.h>

@interface MameOpenGLTexture : NSObject
{
    @public
    const render_primitive * mPrimitive;
	render_texinfo			texinfo;			// copy of the texture info
	UINT32				hash;				// hash value for the texture
	UINT32				flags;				// rendering flags
	float				ustart, ustop;			// beginning/ending U coordinates
	float				vstart, vstop;			// beginning/ending V coordinates
	int				rawwidth, rawheight;		// raw width/height of the texture
	int				type;				// what type of texture are we?
	int				borderpix;			// do we have a 1 pixel border?
	int				xprescale;			// what is our X prescale factor?
	int				yprescale;			// what is our Y prescale factor?
	int				uploadedonce;			// were we uploaded once already?
    
    CVPixelBufferRef    data;
    CVOpenGLTextureRef  cv_texture;
}

+ (UINT32) computeHashForPrimitive: (const render_primitive *) primitive;

- (id) initWithPrimitive: (const render_primitive *) primitive
            textureCache: (CVOpenGLTextureCacheRef) textureCache;

- (BOOL) isEqualToPrimitive: (const render_primitive *) primitive;

- (UINT32) sequenceId;

- (void) computeSize;

- (void) setData: (CVOpenGLTextureCacheRef) textureCache;

- (void) updateData: (const render_primitive *) primitive
       textureCache: (CVOpenGLTextureCacheRef) textureCache;


#if 0
- (UINT32) hash;
- (void *) base;
- (UINT32) width;
- (UINT32) height;
#endif


@end
