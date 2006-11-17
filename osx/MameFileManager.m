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

#include <sys/types.h>
#include <sys/stat.h>
#import "osdepend.h"
#import "MameFileManager.h"

struct _osd_file
{
    FILE * fileHandle;
};

@interface MameFileManager (Private)

@end

@implementation MameFileManager

- (id) init
{
    if ([super init] == nil)
        return nil;
    
    mPathsByType = [[NSMutableDictionary alloc] init];
  
    return self;
}

- (void) dealloc
{
    [mPathsByType release];
    [super dealloc];
}

- (void) setPaths: (NSArray *) paths forType: (int) pathtype;
{
    [mPathsByType setObject: paths forKey: [NSNumber numberWithInt: pathtype]];
}

- (void) setPath: (NSString *) path forType: (int) pathtype;
{
    [self setPaths: [NSArray arrayWithObject: path] forType: pathtype];
}

- (NSArray *) pathsForType: (int) pathtype;
{
    NSArray * paths = [mPathsByType objectForKey: [NSNumber numberWithInt: pathtype]];
    if (paths == nil)
    {
        paths = [NSArray arrayWithObject: @""];
        [mPathsByType setObject: paths forKey: [NSNumber numberWithInt: pathtype]];
    }
    return paths;
}

- (NSString *) composePathForFile: (const char *) utf8File
                           ofType: (int) pathtype
                          atIndex: (int) index;
{
    NSString * file = [NSString stringWithUTF8String: utf8File];
    NSArray * paths = [self pathsForType: pathtype];
    if (index >= [paths count])
        return nil;
    
    NSString * path = [paths objectAtIndex: index];
    return [path stringByAppendingPathComponent: file];
}

- (NSString *) resolveAlias: (NSString *) path
{
    NSString *resolvedPath = nil;
    if ([path isAbsolutePath])
        resolvedPath = @"/";
        
    //Parse the given path and if any part is an alias return the resolved path
    CFURLRef url;
    
    //As the given path could contain an alias anywhere we need to parse each
    //element of the path individually and compose the result
    NSArray *pathElements = [path componentsSeparatedByString: @"/"];
    NSEnumerator *pathEnum = [pathElements objectEnumerator];
    id element;
    
    while (element = [pathEnum nextObject])
    {
        //If this is an absolute path then the first element of the array will be empty
        if ((NSString *)[element length] > 0)
        {
            resolvedPath = [resolvedPath stringByAppendingPathComponent: element];
            //NSLog(@"Trying to parse: %@", resolvedPath);
            
            NSString *tmpPath = nil;
            url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)resolvedPath, kCFURLPOSIXPathStyle, YES);
            if (url != NULL)
            {
                FSRef fsRef;
                if (CFURLGetFSRef(url, &fsRef))
                {
                    Boolean targetIsFolder, wasAliased;
                    if (FSResolveAliasFile (&fsRef, true, &targetIsFolder, &wasAliased) == noErr && wasAliased)
                    {
                        CFURLRef resolvedUrl = CFURLCreateFromFSRef(NULL, &fsRef);
                        if (resolvedUrl != NULL)
                        {
                            tmpPath = (NSString*) CFURLCopyFileSystemPath(resolvedUrl, kCFURLPOSIXPathStyle);
                            CFRelease(resolvedUrl);
                        }
                    }
                }
                CFRelease(url);
            }
            if (tmpPath != nil)
                resolvedPath = tmpPath;
        }
    }

    if (resolvedPath == nil)    //Resolved path SHOULD always be sommething but it doesn't hurt to ensure we never return nil!
        resolvedPath = [[NSString alloc] initWithString:path];
    return resolvedPath;
}

- (int) osd_get_path_count: (int) pathtype;
{
    NSArray * paths = [self pathsForType: pathtype];
    return [paths count];
}

- (int) osd_get_path_info: (int) pathtype
                pathindex: (int) pathindex
                 filename: (const char *) filename;
{
    NSString * fullPath = [self composePathForFile: filename
                                            ofType: pathtype
                                           atIndex: pathindex];
    
	struct stat stats;
    long attributes = stat([fullPath UTF8String], &stats);
    if (attributes != 0)
		return PATH_NOT_FOUND;
	else if (S_ISDIR(stats.st_mode))
		return PATH_IS_DIRECTORY;
	else
		return PATH_IS_FILE;
    
    
    return -1;
}

- (osd_file *) osd_fopen: (int) pathtype
               pathindex: (int) pathindex
                filename: (const char *) filename
                    mode: (const char *) mode
                   error: (osd_file_error *) error;
{
    NSString * fullPath = [self composePathForFile: filename
                                            ofType: pathtype
                                           atIndex: pathindex];
    FILE * handle = fopen([fullPath UTF8String], mode);
    
    if (handle == 0)
    {
        *error = FILEERR_FAILURE;
        return 0;
    }
    
    osd_file * fileStruct = malloc(sizeof(fileStruct));
    if (fileStruct == 0)
    {
        fclose(handle);
        *error = FILEERR_OUT_OF_MEMORY;
        return 0;
    }
    
    fileStruct->fileHandle = handle;
    *error = FILEERR_SUCCESS;
    return fileStruct;
}

- (void) osd_fclose: (osd_file *) file;
{
    fclose(file->fileHandle);
    free(file);
}

- (int) osd_fseek: (osd_file *) file
           offset: (INT64) offset
           whence: (int) whence;
{
    return fseek(file->fileHandle, offset, whence);
}

- (UINT64) osd_ftell: (osd_file *) file;
{
    return ftell(file->fileHandle);
}

- (int) osd_feof: (osd_file *) file;
{
    return feof(file->fileHandle);
}

- (UINT32) osd_fread: (osd_file *) file
              buffer: (void *) buffer
              length: (UINT32) length;
{
    return fread(buffer, 1, length, file->fileHandle);
}


- (UINT32) osd_fwrite: (osd_file *) file
               buffer: (const void *) buffer
               length: (UINT32) length;
{
    return fwrite(buffer, 1, length, file->fileHandle);
}

@end

