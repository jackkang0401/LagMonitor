//
//  SMLagDB.h
//  DecoupleDemo
//
//  Created by DaiMing on 2017/8/3.
//  Copyright © 2017年 Starming. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>
#import "SMCallTraceTimeCostModel.h"
#import "SMCallStackModel.h"

#define PATH_OF_APP_HOME    NSHomeDirectory()
#define PATH_OF_TEMP        NSTemporaryDirectory()
#define PATH_OF_DOCUMENT    [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]

#define CPUMONITORRATE 80
#define STUCKMONITORRATE 88

NS_ASSUME_NONNULL_BEGIN

@interface SMLagDB : NSObject

+ (SMLagDB *)shareInstance;

/*------------卡顿和CPU超标堆栈---------------*/

/// 添加 Stack 记录
/// @param model 记录数据模型
- (void)increaseWithStackModel:(SMCallStackModel *)model;

/// 分页查询 Stack 数据
/// @param page 第 page 页 从1开始
/// @param completion 查询完毕回调
- (void)selectStackWithPage:(NSUInteger)page completion:(void (^ __nullable)(NSArray *array))completion;

/// 清空 Stack 数据
- (void)clearStackData;


/*------------ClsCall方法调用频次-------------*/

/// 添加 Trace 记录
/// @param model 记录数据模型
- (void)addWithClsCallModel:(SMCallTraceTimeCostModel *)model;

/// 分页查询 Trace 数据
/// @param page 第 page 页 从1开始
/// @param completion 查询完毕回调
- (void)selectClsCallWithPage:(NSUInteger)page completion:(void (^ __nullable)(NSArray *array))completion;

/// 清除 Trace 数据
- (void)clearClsCallData;


@end

NS_ASSUME_NONNULL_END
