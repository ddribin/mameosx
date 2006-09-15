//
//  CircularBuffer.h
//  mameosx
//
//  Created by Dave Dribin on 9/8/06.
//

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
