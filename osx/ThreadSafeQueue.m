/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#import "ThreadSafeQueue.h"


@implementation ThreadSafeQueue

-(id)init {
    if (self = [super init]) {
        elements = [[NSMutableArray alloc] init];
        lock = [[NSConditionLock alloc] initWithCondition:0];
    }
    return self;
}

-(void)enqueue:(id)object {
    [lock lock];
    [elements addObject:object];
    [lock unlockWithCondition:1];
}

-(id)dequeue {
    [lock lockWhenCondition:1];
    id element = [[[elements objectAtIndex:0] retain] autorelease];
    [elements removeObjectAtIndex:0];
    int count = [elements count];
    [lock unlockWithCondition:(count > 0)?1:0];
    return element;
}

-(id)tryDequeue {
    id element = NULL;
    if ([lock tryLock]) {
        if ([lock condition] == 1) {
            element = [[[elements objectAtIndex:0] retain] autorelease];
            [elements removeObjectAtIndex:0];
        }
        int count = [elements count];
        [lock unlockWithCondition:(count > 0)?1:0];
    }
    return element;
}

-(void)dealloc {
    [elements release];
    [lock release];
    [super dealloc];
}

@end
