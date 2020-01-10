//
//  SMClsCallCell.m
//  DecoupleDemo
//
//  Created by DaiMing on 2017/8/14.
//  Copyright © 2017年 Starming. All rights reserved.
//

#import "SMClsCallCell.h"

@interface SMClsCallCell()

@property (nonatomic, strong) UILabel *nameLb;
@property (nonatomic, strong) UILabel *desLb;
@property (nonatomic, strong) UILabel *pathLb;

@end

@implementation SMClsCallCell

- (instancetype)init {
    if (self = [super init]) {
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    [self.contentView addSubview:self.nameLb];
    [self.contentView addSubview:self.desLb];
    [self.contentView addSubview:self.pathLb];
    
    CGFloat width = CGRectGetWidth(self.contentView.frame);
    self.nameLb.frame = CGRectMake(10.f, 10.f, width-20.f, 16.f);
    
    CGFloat desY = CGRectGetMaxY(self.nameLb.frame)+10.f;
    self.desLb.frame = CGRectMake(10.f, desY, width-20.f, 12.f);
    
    CGFloat pathY = CGRectGetMaxY(self.desLb.frame)+10.f;
    self.pathLb.frame = CGRectMake(10, pathY, width-20.f, 12.f);
}

- (void)updateWithModel:(SMCallTraceTimeCostModel *)model {
    self.nameLb.text = [NSString stringWithFormat:@"[%@ %@]",model.className,model.methodName];
    self.desLb.text = [NSString stringWithFormat:@"频次:%lu 耗时:%f",(unsigned long)model.frequency, model.timeCost * 1000];
    self.pathLb.text = model.path;
    CGRect frame = [model.path boundingRectWithSize:CGSizeMake([UIScreen mainScreen].bounds.size.width - 10*2, 999) options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12]} context:nil];
    self.pathLb.frame = CGRectMake(10, CGRectGetMinY(self.pathLb.frame), CGRectGetWidth(self.pathLb.frame), ceil(frame.size.height));
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.pathLb.preferredMaxLayoutWidth = self.pathLb.frame.size.width;
}

- (UILabel *)nameLb {
    if (!_nameLb) {
        _nameLb = [[UILabel alloc] init];
        _nameLb.font = [UIFont boldSystemFontOfSize:16];
        _nameLb.textColor = [UIColor grayColor];
    }
    return _nameLb;
}

- (UILabel *)desLb {
    if (!_desLb) {
        _desLb = [[UILabel alloc] init];
        _desLb.font = [UIFont systemFontOfSize:12];
        _desLb.textColor = [UIColor grayColor];
    }
    return _desLb;
}

- (UILabel *)pathLb {
    if (!_pathLb) {
        _pathLb = [[UILabel alloc] init];
        _pathLb.numberOfLines = 0;
        _pathLb.font = [UIFont systemFontOfSize:12];
        _pathLb.textColor = [UIColor lightGrayColor];
    }
    return _pathLb;
}

@end
