/*
 * Copyright (c) 2006 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <Cocoa/Cocoa.h>

typedef int osd_file_error;

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

#pragma mark -
#pragma mark MAME OSD API
   
- (mame_file_error) osd_open: (const char *) path
                       flags: (UINT32) openflags
                        file: (osd_file **) file
                    filesize: (UINT64 *) filesize;

- (mame_file_error) osd_close: (osd_file *) file;

- (mame_file_error) osd_read: (osd_file *) file
                      buffer: (void *) buffer
                      offset: (UINT64) offset
                      length: (UINT32) length
                      actual: (UINT32 *) actual;

- (mame_file_error) osd_write: (osd_file *) file
                       buffer: (const void *) buffer
                       offset: (UINT64) offset
                       length: (UINT32) length
                       actual: (UINT32 *) actual;

#if 0
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
#endif



@end
