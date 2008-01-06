//
//  MameFileLogger.m
//  mameosx
//
//  Created by Dave Dribin on 1/6/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "MameFileLogger.h"
#include <unistd.h>


@implementation MameFileLogger

+ (id) defaultLogger;
{
    static MameFileLogger * logger = nil;
    if (logger == nil)
        logger = [[MameFileLogger alloc] initWithPath: @""];
    return logger;
}

+ (void) rotateLogAtPath: (NSString *) path rotations: (int) rotations;
{
    
}

- (id) initWithPath: (NSString *) path;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    NSLog(@"STDERR_FILENO: %d, stderr: %d, isatty: %d", STDERR_FILENO, fileno(stderr),
          isatty(STDERR_FILENO));
    
    return self;
}

- (void)logWithLevel:(JRLogLevel)callerLevel_
			instance:(NSString*)instance_
				file:(const char*)file_
				line:(unsigned)line_
			function:(const char*)function_
			 message:(NSString*)message_;
{
    // "MyClass.m:123: blah blah"
    NSLog(@"<foo> %@:%u: %@",
          [[NSString stringWithUTF8String:file_] lastPathComponent],
          line_,
          message_);
}

@end
