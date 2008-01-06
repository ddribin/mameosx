//
//  MameFileLogger.h
//  mameosx
//
//  Created by Dave Dribin on 1/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JRLog.h"

@interface MameFileLogger : NSObject<JRLogLogger>
{
    NSFileHandle * mFileHandle;
}

+ (id) defaultLogger;

+ (void) rotateLogAtPath: (NSString *) path rotations: (int) rotations;

- (id) initWithPath: (NSString *) path;

- (void)logWithLevel:(JRLogLevel)callerLevel_
			instance:(NSString*)instance_
				file:(const char*)file_
				line:(unsigned)line_
			function:(const char*)function_
			 message:(NSString*)message_;

@end
