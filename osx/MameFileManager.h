//
//  MameFileManager.h
//  mameosx
//
//  Created by Dave Dribin on 9/16/06.
//

#import <Cocoa/Cocoa.h>


@interface MameFileManager : NSObject
{
    NSMutableDictionary * mPathsByType;
}

- (void) setPaths: (NSArray *) paths forType: (int) pathtype;

- (void) setPath: (NSString *) path forType: (int) pathtype;

- (NSArray *) pathsForType: (int) pathtype;

- (NSString *) composePathForFile: (const char *) utf8File
                           ofType: (int) pathtype
                          atIndex: (int) index;

- (NSString *) resolveAlias: (NSString *) path;

- (int) osd_get_path_count: (int) pathtype;

- (int) osd_get_path_info: (int) pathtype
                pathindex: (int) pathindex
                 filename: (const char *) filename;

- (osd_file *) osd_fopen: (int) pathtype
               pathindex: (int) pathindex
                filename: (const char *) filename
                    mode: (const char *) mode
                   error: (osd_file_error *) error;

- (void) osd_fclose: (osd_file *) file;

- (int) osd_fseek: (osd_file *) file
           offset: (INT64) offset
           whence: (int) whence;

- (UINT64) osd_ftell: (osd_file *) file;

- (int) osd_feof: (osd_file *) file;

- (UINT32) osd_fread: (osd_file *) file
              buffer: (void *) buffer
              length: (UINT32) length;

- (UINT32) osd_fwrite: (osd_file *) file
               buffer: (const void *) buffer
               length: (UINT32) length;



@end
