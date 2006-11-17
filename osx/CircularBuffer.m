/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import "CircularBuffer.h"

@interface CircularBuffer (Private)

- (NSData *) backingData;

@end



@implementation CircularBuffer

- (id) initWithCapacity: (unsigned) capacity
{
    if ([super init] == nil)
        return;
    
    mCapacity = capacity;
    mBuffer = [[NSMutableData alloc] initWithLength: mCapacity];
    mReadCursor = 0;
    mWriteCursor = 0;
    mSize = 0;
   
    return self;
}

- (void) dealloc
{
    [mBuffer release];
    [super dealloc];
}

- (unsigned) size;
{
    return mSize;
}

- (unsigned) capacity;
{
    return mCapacity;
}

- (unsigned) writeBytes: (const void *) buffer length: (unsigned) length;
{
    @synchronized(self)
    {
        uint8_t * bytes = (uint8_t *) buffer;
#if 1
        unsigned bytesLeft = mCapacity - mSize;
        if (length > bytesLeft)
        {
            unsigned dropBytes = MIN(length - bytesLeft, mSize);
            mReadCursor += dropBytes;
            mReadCursor %= mCapacity;
            mSize -= dropBytes;
        }
#endif
        
        unsigned bytesToWrite = MIN(length, mCapacity - mSize);
        unsigned bytesToEndOfBuffer = mCapacity - mWriteCursor;
        unsigned bytesInFirstRange = MIN(bytesToEndOfBuffer, bytesToWrite);
        [mBuffer replaceBytesInRange: NSMakeRange(mWriteCursor, bytesInFirstRange)
                           withBytes: bytes];
        mSize += bytesInFirstRange;
        mWriteCursor += bytesInFirstRange;
        mWriteCursor %= mCapacity;
        
        unsigned bytesInSecondRange = bytesToWrite - bytesInFirstRange;
        if (bytesInSecondRange == 0)
            return bytesToWrite;
        
        [mBuffer replaceBytesInRange: NSMakeRange(mWriteCursor, bytesInSecondRange)
                           withBytes: bytes + bytesInFirstRange];
        mSize += bytesInSecondRange;
        mWriteCursor += bytesInSecondRange;
        
        return bytesToWrite;
    }
}

- (unsigned) readBytes: (const void *) buffer length: (unsigned) length;
{
    @synchronized(self)
    {
        uint8_t * bytes = (uint8_t *) buffer;
        unsigned bytesToRead = MIN(length, mSize);
        unsigned bytesToEndOfBuffer = mCapacity - mReadCursor;
        unsigned bytesInFirstRange = MIN(bytesToEndOfBuffer, bytesToRead);
        assert(mReadCursor + bytesInFirstRange <= mCapacity);
        [mBuffer getBytes: bytes
                    range: NSMakeRange(mReadCursor, bytesInFirstRange)];
        mSize -= bytesInFirstRange;
        mReadCursor += bytesInFirstRange;
        mReadCursor %= mCapacity;
        
        unsigned bytesInSecondRange = bytesToRead - bytesInFirstRange;
        if (bytesInSecondRange == 0)
            return bytesToRead;
        
        assert(mReadCursor + bytesInSecondRange <= mCapacity);
        [mBuffer getBytes: bytes + bytesInFirstRange
                    range: NSMakeRange(mReadCursor, bytesInSecondRange)];
        mSize -= bytesInSecondRange;
        mReadCursor += bytesInSecondRange;
        return bytesToRead;
    }
}


@end

@implementation CircularBuffer (Private)

- (NSData *) backingData;
{
    return mBuffer;
}

@end

