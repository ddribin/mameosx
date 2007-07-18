#import "AOSegmentedControl.h"

#define NormalSegmentedCellStyle 1
#define FlatSegmentedCellStyle 2

@interface NSSegmentedCell ( PrivateMethod )
- (void)_setSegmentedCellStyle:(int)style;
@end

@implementation AOSegmentedControl

- (void)awakeFromNib
{
    [self setFrameSize:NSMakeSize([self frame].size.width, 26)];
}

- (NSCell *)cell
{
    NSSegmentedCell *cell = [super cell];
    [cell _setSegmentedCellStyle:FlatSegmentedCellStyle];
    return cell;
}

@end