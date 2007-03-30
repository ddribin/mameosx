/*
 *  MameChud.h
 *  mameosx
 *
 *  Created by Dave Dribin on 3/29/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

#if DEBUG_INSTRUMENTED

#import <CHUD/CHUD.h>

#define MameGameStart 0x00
#define MameGameEnd 0x01
#define MameGetPrimitives 0x02
#define MameRenderFrame 0x03
#define MameSkipFrame 0x04

#define MameLockAcquire 0x100
#define MameLockTry 0x101
#define MameLockRelease 0x102

#endif
