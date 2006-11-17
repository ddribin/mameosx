/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

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
