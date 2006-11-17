/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import <Cocoa/Cocoa.h>


@interface CircularBuffer : NSObject
{
    NSMutableData * mBuffer;
    
    unsigned mReadCursor;
    unsigned mWriteCursor;
    unsigned mSize;
    unsigned mCapacity;
}

- (id) initWithCapacity: (unsigned) capacity;

- (unsigned) writeBytes: (const void *) buffer length: (unsigned) length;

- (unsigned) readBytes: (const void *) buffer length: (unsigned) length;

- (unsigned) size;

- (unsigned) capacity;

@end
