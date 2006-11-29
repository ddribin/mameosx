/*
 *  osx_ppc.c
 *  mameosx
 *
 *  Created by Dave Dribin on 11/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */


#if __i386__
#include "src/cpu/powerpc/ppcdrc.c"
#else
#include "src/cpu/powerpc/ppc.c"
#endif
