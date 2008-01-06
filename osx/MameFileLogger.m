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
    {
        NSString * path = [self defaultPath];
        [self rotateLogAtPath: path rotations: kMameFileLoggerDefaultRotations];
        logger = [[MameFileLogger alloc] initWithPath: path];
    }
    return logger;
}

+ (NSString *) defaultPath;
{
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                          NSUserDomainMask, YES);
    NSAssert([paths count] > 0, @"Could not locate NSLibraryDirectory in user domain");
    
    NSString * library = [paths objectAtIndex: 0];
    NSString * libraryLogs = [library stringByAppendingPathComponent: @"Logs"];
    [fileManager createDirectoryAtPath: libraryLogs attributes: nil];
    NSString * mameLogs = [libraryLogs stringByAppendingPathComponent:
        [[NSBundle mainBundle] bundleIdentifier]];
    [fileManager createDirectoryAtPath: mameLogs attributes: nil];
    
    return [mameLogs stringByAppendingPathComponent: @"mameosx.log"];
}

+ (void) rotateLogAtPath: (NSString *) path rotations: (int) rotations;
{
    if (rotations < 1)
        return;
    
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSString * lastLog = [NSString stringWithFormat: @"%@.%d", path, rotations];
    if ([fileManager fileExistsAtPath: lastLog])
        [fileManager removeFileAtPath: lastLog handler: NULL];

    int i;
    for (i = rotations-1; i >= 1; i--)
    {
        NSString * currentLog = [NSString stringWithFormat: @"%@.%d", path, i];
        NSString * rotatedLog = [NSString stringWithFormat: @"%@.%d", path, i+1];
        
        if ([fileManager fileExistsAtPath: currentLog])
            [fileManager movePath: currentLog toPath: rotatedLog handler: nil];
    }
    
    NSString * firstRotation = [NSString stringWithFormat: @"%@.1", path];
    if ([fileManager fileExistsAtPath: path])
        [fileManager movePath: path toPath: firstRotation handler: nil];

}

- (id) initWithPath: (NSString *) path;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    NSLog(@"STDERR_FILENO: %d, stderr: %d, isatty: %d", STDERR_FILENO, fileno(stderr),
          isatty(STDERR_FILENO));
    
    CFLocaleRef currentLocale = CFLocaleCopyCurrent();
    mDateFormatter = CFDateFormatterCreate(
        NULL, currentLocale, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle);
    CFStringRef customDateFormat = CFSTR("yyyy-MM-dd HH:mm:ss.SSS");
    CFDateFormatterSetFormat(mDateFormatter, customDateFormat);
    CFRelease(currentLocale);
    
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSString * directory = [path stringByDeletingLastPathComponent];
    [fileManager createDirectoryAtPath: directory attributes: nil];
    [fileManager createFileAtPath: path contents: nil attributes: nil];
    mFileHandle = [[NSFileHandle fileHandleForWritingAtPath: path] retain];
    
    return self;
}

- (void)logWithLevel:(JRLogLevel)callerLevel_
			instance:(NSString*)instance_
				file:(const char*)file_
				line:(unsigned)line_
			function:(const char*)function_
			 message:(NSString*)message_;
{
    // Since this may get called frequently, use our own poo
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    @try
    {
        NSString * dateString = (NSString *)
            CFDateFormatterCreateStringWithAbsoluteTime
                (NULL, mDateFormatter, CFAbsoluteTimeGetCurrent());
        [dateString autorelease];
        
        NSString * finalMessage = [NSString stringWithFormat:
            @"%@ %@:%u: %@\n",
            dateString,
            [[NSString stringWithUTF8String:file_] lastPathComponent],
            line_,
            message_];

        NSData * utf8Data = [finalMessage dataUsingEncoding: NSUTF8StringEncoding];
        [mFileHandle writeData: utf8Data];

        if (callerLevel_ >= JRLogLevel_Warn)
            fprintf(stderr, "%s", [utf8Data bytes]);
    }
    @finally
    {
        [pool release];
    }
}

- (void) flushLogFile;
{
    [mFileHandle synchronizeFile];
}

@end
