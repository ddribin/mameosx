//
//  ThreadSafeQueue.h
//  mameosx
//
//  Created by Dave Dribin on 9/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ThreadSafeQueue : NSObject {
    NSMutableArray* elements;
    NSConditionLock* lock; // 0 = no elements, 1 = elements
}

-(id)init;
-(void)enqueue:(id)object;
-(id)dequeue; // Blocks until there is an object to return
-(id)tryDequeue; // Returns NULL if the queue is empty
-(void)dealloc;

@end