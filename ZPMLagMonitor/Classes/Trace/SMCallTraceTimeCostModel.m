//
//  SMCallTraceTimeCostModel.m
//  DecoupleDemo
//
//  Created by DaiMing on 2017/7/15.
//  Copyright © 2017年 Starming. All rights reserved.
//

#import "SMCallTraceTimeCostModel.h"

@implementation SMCallTraceTimeCostModel

- (NSMutableArray <SMCallTraceTimeCostModel *> *)subCosts{
    if(!_subCosts){
        _subCosts = [[NSMutableArray alloc] init];
    }
    return _subCosts;
}

- (NSString *)des {
    NSMutableString *str = [NSMutableString new];
    [str appendFormat:@"%2d| ",(int)_callDepth];
    [str appendFormat:@"%6.2fms|",_timeCost * 1000.0];
    for (NSUInteger i = 0; i < _callDepth; i++) {
        [str appendString:@"  "];
    }
    [str appendFormat:@"%s[%@ %@]", (_isClassMethod ? "+" : "-"), _className, _methodName];
    return str;
}

- (NSString *)description{
    // 深度
    NSString *str = [NSString stringWithFormat:@" %@ ", @(self.callDepth)];
    // 空格数
    for (NSInteger i=0; i<self.callDepth; i++) {
        str = [str stringByAppendingString:@"  "];
    }
    // 类方法/普通方法
    str = [str stringByAppendingFormat:@" %@ ",self.isClassMethod?@"+":@"-"];
    // 类名、方法、包含方法数
    str = [str stringByAppendingFormat:@"[%@ %@] %@ms ",self.className,self.methodName,@(self.timeCost)];
    // 子类信息
    if (self.subCosts.count) {
        str = [str stringByAppendingFormat:@"  %@ ",@(self.subCosts.count)];
        for (SMCallTraceTimeCostModel *model in self.subCosts) {
            NSString *subString = [NSString stringWithFormat:@"%@",model];
            str = [str stringByAppendingFormat:@"\n%@",subString];
        }
    }
    return str;
}

@end
