//
//  MameFileManagerTest.m
//  mameosx
//
//  Created by Dave Dribin on 9/16/06.
//

#include "osdepend.h"
#include "render.h"
#import "MameFileManagerTest.h"
#import "MameFileManager.h"

@implementation MameFileManagerTest

- (void) setUp
{
    mFileManager = [[MameFileManager alloc] init];
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    mResourcePath = [[myBundle resourcePath] retain];
        
#if 0
    NSBundle * myBundle = [NSBundle bundleForClass: [self class]];
    NSArray * paths = [NSArray arrayWithObject: [myBundle resourcePath]];
    [mFileManager setPaths: paths forType: FILETYPE_ROM];
    paths = [NSArray arrayWithObject: [myBundle bundlePath]];
    [mFileManager setPaths: paths forType: FILETYPE_SAMPLE];
    [mFileManager setPaths: [NSArray array] forType: FILETYPE_INI];
     paths = [NSArray arrayWithObjects: @"/tmp", @"/Users", nil];
    [mFileManager setPaths: paths
                   forType: FILETYPE_SCREENSHOT];
#endif
}

- (void) tearDown
{
    [mFileManager release];
    [mResourcePath release];
}

- (const char *) path: (NSString *) resource;
{
    NSString * path = [mResourcePath stringByAppendingPathComponent: resource];
    return [path UTF8String];
}

#if 0
- (void) testInitialCount
{
    STAssertEquals([mFileManager osd_get_path_count: FILETYPE_FONT], 1, nil);
}

- (void) testInitialPathsForType
{
    NSArray * expected = [NSArray arrayWithObject: @""];
    STAssertEqualObjects([mFileManager pathsForType: FILETYPE_FONT], expected,
                         nil);
}

- (void) testEmptyPathArrayCount
{
    STAssertEquals([mFileManager osd_get_path_count: FILETYPE_INI], 0, nil);
}

- (void) testEmptyPathArray
{
    STAssertEqualObjects([mFileManager pathsForType: FILETYPE_INI],
                         [NSArray array], nil);
}

- (void) testPathArrayCount
{
    STAssertEquals([mFileManager osd_get_path_count: FILETYPE_SCREENSHOT], 2, nil);
}

- (void) testPathArray
{
    NSArray * expected = [NSArray arrayWithObjects: @"/tmp", @"/Users", nil];
    STAssertEqualObjects([mFileManager pathsForType: FILETYPE_SCREENSHOT],
                         expected, nil);
}

- (void) testComposePath
{ 
    NSString * fullPath = [mFileManager composePathForFile: "file.txt"
                                                    ofType: FILETYPE_ROM
                                                   atIndex: 0];
    NSString * resourcePath = [[NSBundle bundleForClass: [self class]] resourcePath];
    NSString * expected = [resourcePath stringByAppendingString: @"/file.txt"];
    STAssertEqualObjects(fullPath, expected, nil);
}

- (void) testComposePathForNonexistantIndex
{ 
    NSString * fullPath = [mFileManager composePathForFile: "file.txt"
                                                    ofType: FILETYPE_FONT
                                                   atIndex: 0];
    STAssertEqualObjects(fullPath, @"file.txt", nil);
}

- (void) testGetPathIsFile
{
    int rc = [mFileManager osd_get_path_info: FILETYPE_ROM
                                   pathindex: 0
                                    filename: "file.txt"];
    STAssertEquals(rc, PATH_IS_FILE, nil);
    
}

- (void) testGetPathNotFound
{
    int rc = [mFileManager osd_get_path_info: FILETYPE_ROM
                                   pathindex: 0
                                    filename: "nonexistent"];
    STAssertEquals(rc, PATH_NOT_FOUND, nil);
    
}

- (void) testGetPathIsDirectory
{
    int rc = [mFileManager osd_get_path_info: FILETYPE_SAMPLE
                                   pathindex: 0
                                    filename: "Contents"];
    STAssertEquals(rc, PATH_IS_DIRECTORY, nil);
    
}

- (void) testOpenFileForReading
{
    osd_file_error error;
    osd_file * file = [mFileManager osd_fopen: FILETYPE_ROM
                                    pathindex: 0
                                     filename: "file.txt"
                                         mode: "r"
                                        error: &error];
    STAssertEquals(error, FILEERR_SUCCESS, nil);
    STAssertFalse(file == 0, nil);
    [mFileManager osd_fclose: file];
    
}
#endif

- (void) testReadFile
{
    osd_file * file = 0;
    UINT64 fileSize = 0;
    mame_file_error error = [mFileManager osd_open: [self path: @"file.txt"]
                                             flags: OPEN_FLAG_READ
                                              file: &file
                                          filesize: &fileSize];
    STAssertEquals(error, FILERR_NONE, nil);
    STAssertFalse(file == 0, nil);
    STAssertEquals(fileSize, 5ULL, nil);
    
    unsigned char expectedBytes[] = {'H', 'e', 'l', 'l', 0x55, 0x55};
    NSData * expected = [NSData dataWithBytes: expectedBytes
                                       length: sizeof(expectedBytes)];
    unsigned char buffer[6];
    memset(buffer, 0x55, sizeof(buffer));
    UINT32 actualSize;
    error = [mFileManager osd_read: file
                            buffer: buffer
                            offset: 0
                            length: 4
                            actual: &actualSize];
    STAssertEquals(error, FILERR_NONE, nil);
    NSData * actual = [NSData dataWithBytesNoCopy: buffer
                                           length: sizeof(buffer)];
    STAssertEqualObjects(actual, expected, nil);
    STAssertEquals(actualSize, 4U, nil);

    unsigned char expectedBytes2[] = {'l', 'o', 0x55, 0x55, 0x55, 0x55,};
    expected = [NSData dataWithBytes: expectedBytes2
                              length: sizeof(expectedBytes2)];
    memset(buffer, 0x55, sizeof(buffer));
    error = [mFileManager osd_read: file
                            buffer: buffer
                            offset: 3
                            length: 4
                            actual: &actualSize];
    STAssertEquals(error, FILERR_NONE, nil);
    actual = [NSData dataWithBytesNoCopy: buffer
                                  length: sizeof(buffer)];
    STAssertEqualObjects(actual, expected, nil);
    STAssertEquals(actualSize, 2U, nil);
    
    error = [mFileManager osd_close: file];
    STAssertEquals(error, FILERR_NONE, nil);
}

- (void) testOpenNonExistantFile
{
    osd_file * file = 0;
    UINT64 fileSize = 0;
    mame_file_error error = [mFileManager osd_open: [self path: @"nonexistant"]
                                             flags: OPEN_FLAG_READ
                                              file: &file
                                          filesize: &fileSize];
    STAssertEquals(error, FILERR_NOT_FOUND, nil);
}

- (void) testOpenWithNullSize
{
    osd_file * file = 0;
    mame_file_error error = [mFileManager osd_open: [self path: @"file.txt"]
                                             flags: OPEN_FLAG_READ
                                              file: &file
                                          filesize: NULL];
    STAssertEquals(error, FILERR_NONE, nil);
    STAssertFalse(file == 0, nil);

    error = [mFileManager osd_close: file];
    STAssertEquals(error, FILERR_NONE, nil);
}

- (void) testCreateAndWrite
{
    NSString * tempFile = @"/tmp/net.mame.mameosx.tmp";
    NSFileManager * fileManager = [NSFileManager defaultManager];
    [fileManager removeFileAtPath: tempFile
                          handler: nil];
    
    osd_file * file = 0;
    mame_file_error error = [mFileManager osd_open: [tempFile UTF8String]
                                             flags: OPEN_FLAG_WRITE | OPEN_FLAG_CREATE
                                              file: &file
                                          filesize: NULL];
    STAssertEquals(error, FILERR_NONE, nil);
    STAssertFalse(file == 0, nil);
    
    UINT32 actualSize;
    uint8_t bytes[] = {'H', 'e', 'x', 'x'};
    error = [mFileManager osd_write: file
                             buffer: bytes
                             offset: 0
                             length: sizeof(bytes)
                             actual: &actualSize];
    STAssertEquals(error, FILERR_NONE, nil);
    STAssertEquals(actualSize, 4U, nil);
    
    uint8_t bytes2[] = {'l', 'l', 'o'};
    error = [mFileManager osd_write: file
                             buffer: bytes2
                             offset: 2
                             length: sizeof(bytes2)
                             actual: &actualSize];
    STAssertEquals(error, FILERR_NONE, nil);
    STAssertEquals(actualSize, 3U, nil);

    error = [mFileManager osd_close: file];
    STAssertEquals(error, FILERR_NONE, nil);
    NSData * expected = [@"Hello" dataUsingEncoding: NSUTF8StringEncoding];
    NSData * actual = [NSData dataWithContentsOfFile: tempFile];
    STAssertEqualObjects(actual, expected, nil);
}

@end
