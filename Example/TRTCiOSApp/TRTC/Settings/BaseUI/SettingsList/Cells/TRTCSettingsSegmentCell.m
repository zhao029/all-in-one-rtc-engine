/*
* Module:   TRTCSettingsSegmentCell
*
* Function: 配置列表Cell，右侧是SegmentedControl
*
*/

#import "TRTCSettingsSegmentCell.h"
#import "UISegmentedControl+TRTC.h"
#import "Masonry.h"
#import "ColorMacro.h"

@interface TRTCSettingsSegmentCell ()

@property (strong, nonatomic) UISegmentedControl *segment;

@end

@implementation TRTCSettingsSegmentCell

- (void)setupUI {
    [super setupUI];
    
    self.segment = [UISegmentedControl trtc_segment];
    [self.segment addTarget:self action:@selector(onSegmentChange:) forControlEvents:UIControlEventValueChanged];
    
    [self.contentView addSubview:self.segment];
    [self.titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(9);
        make.top.equalTo(self.contentView).offset(15);
    }];
    [self.segment mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).offset(-9);
        make.bottom.equalTo(self.contentView).offset(-9);
    }];
}

- (void)didUpdateItem:(TRTCSettingsBaseItem *)item {
    if ([item isKindOfClass:[TRTCSettingsSegmentItem class]]) {
        TRTCSettingsSegmentItem *segmentItem = (TRTCSettingsSegmentItem *)item;
        [self.segment removeAllSegments];
        [segmentItem.items enumerateObjectsUsingBlock:^(NSString * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.segment insertSegmentWithTitle:item atIndex:idx animated:NO];
        }];
        self.segment.selectedSegmentIndex = segmentItem.selectedIndex;
    }
}

- (void)onSegmentChange:(id)sender {
    TRTCSettingsSegmentItem *segmentItem = (TRTCSettingsSegmentItem *)self.item;
    segmentItem.selectedIndex = self.segment.selectedSegmentIndex;
    if (segmentItem.action) {
        segmentItem.action(self.segment.selectedSegmentIndex);
    }
}

@end

@interface TRTCSettingsSegmentItem ()
@property (assign, nonatomic) BOOL singleRow;
@end

@implementation TRTCSettingsSegmentItem

- (instancetype)initWithTitle:(NSString *)title
                        items:(NSArray<NSString *> *)items
                selectedIndex:(NSInteger)index
                       action:(void(^ _Nullable)(NSInteger index))action {
    if (self = [super init]) {
        self.title = title;
        _items = items;
        _selectedIndex = index;
        _action = action;
        UISegmentedControl *segmentControl = [[UISegmentedControl alloc] initWithItems:items];
        [segmentControl trtc_setupApperance];
        [segmentControl sizeToFit];
        CGSize size = segmentControl.frame.size;
        _singleRow = size.width < [UIScreen mainScreen].bounds.size.width * 0.66666;
    }
    return self;
}

+ (Class)bindedCellClass {
    return [TRTCSettingsSegmentCell class];
}

- (CGFloat)height {
    return _singleRow ? [super height] : 70;
}

- (NSString *)bindedCellId {
    return [TRTCSettingsSegmentItem bindedCellId];
}

@end

