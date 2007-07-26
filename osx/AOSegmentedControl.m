#import "AOSegmentedControl.h"

#define NormalSegmentedCellStyle 1
#define FlatSegmentedCellStyle 2

@interface NSSegmentedCell ( PrivateMethod )
- (void)_setSegmentedCellStyle:(int)style;
@end

@implementation AOSegmentedControl

- (id) initWithFrame: (NSRect) frame;
{
    return [super initWithFrame: frame];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder: decoder];
    [self setFrameSize:NSMakeSize([self frame].size.width, 26)];
    return self;
}

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