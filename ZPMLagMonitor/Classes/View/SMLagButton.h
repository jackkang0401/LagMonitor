//
//  SMLagButton.h
//  DecoupleDemo
//
//  Created by DaiMing on 2017/8/17.
//  Copyright © 2017年 Starming. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SMLagButton : UIView

@property (nonatomic, copy) void(^clickBlock)(void);

- (instancetype)initWithStr:(NSString *)str size:(CGFloat)size backgroundColor:(UIColor *)color;

@end
