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
    NSArray * paths = [NSArray arrayWithObject: [myBundle resourcePath]];
    [mFileManager setPaths: paths forType: FILETYPE_ROM];
    paths = [NSArray arrayWithObject: [myBundle bundlePath]];
    [mFileManager setPaths: paths forType: FILETYPE_SAMPLE];
    [mFileManager setPaths: [NSArray array] forType: FILETYPE_INI];
     paths = [NSArray arrayWithObjects: @"/tmp", @"/Users", nil];
    [mFileManager setPaths: paths
                   forType: FILETYPE_SCREENSHOT];
}

- (void) tearDown
{
    [mFileManager release];
}

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

@end
