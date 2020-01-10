//
//  SMStackCell.m
//  DecoupleDemo
//
//  Created by DaiMing on 2017/8/17.
//  Copyright © 2017年 Starming. All rights reserved.
//

#import "SMStackCell.h"

@interface SMStackCell()

@property (nonatomic, strong) UILabel *contentLb;
@property (nonatomic, strong) UILabel *dateLb;
@property (nonatomic, strong) UILabel *infoLb;

@end

@implementation SMStackCell

- (instancetype)init {
    if (self = [super init]) {
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    [self.contentView addSubview:self.dateLb];
    [self.contentView addSubview:self.contentLb];
    [self.contentView addSubview:self.infoLb];
    
    CGFloat width = CGRectGetWidth(self.contentView.frame);
    self.dateLb.frame = CGRectMake(10.f, 10.f, width-20.f, 14.f);
    
    CGFloat infoY = CGRectGetMaxY(self.dateLb.frame) + 10.f;
    self.infoLb.frame = CGRectMake(10.f, infoY, width-20.f, 14.f);
    
    CGFloat contentY = CGRectGetMaxY(self.infoLb.frame) + 10.f;
    self.contentLb.frame = CGRectMake(10.f, contentY, width-20.f, 14.f);
}

- (void)updateWithModel:(SMCallStackModel *)model {
    self.contentLb.text = model.stackStr;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss z"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:model.dateString];
    self.dateLb.text = [formatter stringFromDate:date];
    if (model.isStuck) {
        self.infoLb.text = @"卡顿问题";
        self.infoLb.textColor = [UIColor redColor];
    } else {
        self.infoLb.text = @"CPU负载高";
        self.infoLb.textColor = [UIColor orangeColor];
    }
    CGRect frame = [model.stackStr boundingRectWithSize:CGSizeMake([UIScreen mainScreen].bounds.size.width - 10*2, 999) options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12]} context:nil];
     CGFloat height = 70.f + ceil(frame.size.height);
     height = height > 400.f ? 400.f : height;
    self.contentLb.frame = CGRectMake(10.f, CGRectGetMinY(self.contentLb.frame), CGRectGetWidth(self.contentLb.frame), height);
    
}

#pragma mark - Getter
- (UILabel *)contentLb {
    if (!_contentLb) {
        _contentLb = [[UILabel alloc] init];
        _contentLb.numberOfLines = 0;
        _contentLb.font = [UIFont systemFontOfSize:14.f];
        _contentLb.textColor = [UIColor grayColor];
    }
    return _contentLb;
}
- (UILabel *)dateLb {
    if (!_dateLb) {
        _dateLb = [[UILabel alloc] init];
        _dateLb.font = [UIFont boldSystemFontOfSize:14.f];
        _dateLb.textColor = [UIColor grayColor];
    }
    return _dateLb;
}
- (UILabel *)infoLb {
    if (!_infoLb) {
        _infoLb = [[UILabel alloc] init];
        _infoLb.font = [UIFont boldSystemFontOfSize:14.f];
        _infoLb.textColor = [UIColor redColor];
    }
    return _infoLb;
}

@end
