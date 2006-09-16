//
//  CircularBufferTest.m
//  mameosx
//
//  Created by Dave Dribin on 9/8/06.
//  Copyright 2006 Bit Maki, Inc. All rights reserved.
//

#import "CircularBufferTest.h"
#import "CircularBuffer.h"
#include <string.h>

@interface CircularBuffer (Private)
- (NSData *) backingData;
@end


@implementation CircularBufferTest

- (void) setUp
{
    mBuffer = [[CircularBuffer alloc] initWithCapacity: 10];
}

- (void) tearDown
{
    [mBuffer release];
}

- (void) testReadFromEmpty
{
    uint8_t bytes[10];
    unsigned bytesRead;
    bytesRead = [mBuffer readBytes: bytes length: sizeof(bytes)];
    STAssertEquals(bytesRead, 0U, nil);
}

- (void) testWriteLessThanCapacity
{
    uint8_t source[] = { 0x00, 0x01, 0x02 };
    uint8_t * source_p = source;
  
    unsigned rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    
    uint8_t expected[] = { 0, 1, 2, 0, 1, 2, 0, 1, 2};
    uint8_t * expected_p = expected;
    const uint8_t * actual_p = [[mBuffer backingData] bytes];
    STAssertEquals(0, memcmp(expected_p, actual_p, sizeof(expected)), nil);
}


- (void) testWriteWrap
{
    uint8_t source[] = { 0x00, 0x01, 0x02 };
    uint8_t * source_p = source;
    
    unsigned rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    
    uint8_t dest[3];
    uint8_t * dest_p = dest;
    unsigned bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 3U, nil);
  
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);

    uint8_t expected[] = { 1, 2, 2, 0, 1, 2, 0, 1, 2, 0};
    uint8_t * expected_p = expected;
    const uint8_t * actual_p = [[mBuffer backingData] bytes];
    STAssertEquals(0, memcmp(expected_p, actual_p, sizeof(expected)), nil);
}

- (void) testWriteReadLessThanCapacity
{
    uint8_t source[] = { 0x00, 0x01, 0x02 };
    uint8_t dest[10];
    uint8_t * source_p = source;
    uint8_t * dest_p = dest;

    unsigned rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    unsigned bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 6U, nil);
    STAssertEquals(0, memcmp(source_p, dest_p, 3), nil);
    STAssertEquals(0, memcmp(source_p, dest_p+3, 3), nil);
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 0U, nil);
}

- (void) testWriteReadWrap
{
    uint8_t source[] = { 0x00, 0x01, 0x02 };
    uint8_t dest[10];
    uint8_t * source_p = source;
    uint8_t * dest_p = dest;
    unsigned rc, bytesRead;
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 3U, nil);
    STAssertEquals(0, memcmp(source_p, dest_p, 3), nil);

    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 3U, nil);
    STAssertEquals(0, memcmp(source_p, dest_p, 3), nil);
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 3U, nil);
    STAssertEquals(0, memcmp(source_p, dest_p, 3), nil);
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 3U, nil);
    STAssertEquals(0, memcmp(source_p, dest_p, 3), nil);

    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 0U, nil);
}


#if 0
- (void) testOverFlowDropsFromWrite
{
    uint8_t source[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
    uint8_t dest[10];
    uint8_t * source_p = source;
    uint8_t * dest_p = dest;
    unsigned rc, bytesRead;
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 10U, nil);
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 0U, nil);

    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 10U, nil);
    STAssertEquals(0, memcmp(source_p, dest_p, 10), nil);
    
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 0U, nil);
}
#else
- (void) testOverFlowDropsFromRead
{
    uint8_t source[] = {1, 2, 3};
    uint8_t dest[10];
    uint8_t * source_p = source;
    uint8_t * dest_p = dest;
    unsigned rc, bytesRead;
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);

    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);

    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 3U, nil);
    
    //                    1  2  3  1  2  3  1  2  3  1
    //                    2  3
    uint8_t expected[] = {3, 1, 2, 3, 1, 2, 3, 1, 2, 3};
    uint8_t * expected_p = expected;
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 10U, nil);
    STAssertEquals(0, memcmp(expected_p, dest_p, 10), nil);
    
    bytesRead = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(bytesRead, 0U, nil);
}
#endif

- (void) testWriteOverflowWrapsReadCursor
{
    uint8_t source[] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    uint8_t * source_p = source;

    unsigned rc;
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 9U, nil);
    
    uint8_t dest[9];
    uint8_t * dest_p = dest;
    rc = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(rc, 9U, nil);

    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 9U, nil);
    
    rc = [mBuffer writeBytes: source_p length: sizeof(source)];
    STAssertEquals(rc, 9U, nil);

    rc = [mBuffer readBytes: dest_p length: sizeof(dest)];
    STAssertEquals(rc, 9U, nil);

    uint8_t expected[] = {9, 1, 2, 3, 4, 5, 6, 7, 8};
    uint8_t * expected_p = expected;
    STAssertEquals(0, memcmp(expected_p, dest_p, sizeof(expected)), nil);
}


@end
