//
//  SMCallTrace.m
//  HomePageTest
//
//  Created by DaiMing on 2017/7/8.
//  Copyright © 2017年 DiDi. All rights reserved.
//

#import "SMCallTrace.h"
#import "SMCallLib.h"
#import "SMCallTraceTimeCostModel.h"
#import "SMLagDB.h"


@implementation SMCallTrace

#pragma mark - Trace
#pragma mark - OC Interface
+ (void)start {
    smCallTraceStart();
}

+ (void)startWithMaxDepth:(int)depth {
    smCallConfigMaxDepth(depth);
    [SMCallTrace start];
}

+ (void)startWithMinCost:(double)ms {
    smCallConfigMinTime(ms * 1000);
    [SMCallTrace start];
}

+ (void)startWithMaxDepth:(int)depth minCost:(double)ms {
    smCallConfigMaxDepth(depth);
    smCallConfigMinTime(ms * 1000);
    [SMCallTrace start];
}

+ (void)stop {
    smCallTraceStop();
}

+ (void)save {
    NSMutableString *mStr = [NSMutableString new];
    NSArray<SMCallTraceTimeCostModel *> *arr = [self loadRecords];
    for (SMCallTraceTimeCostModel *model in arr) {
        //记录方法路径
        model.path = [NSString stringWithFormat:@"[%@ %@]",model.className,model.methodName];
        [self appendRecord:model to:mStr];
    }
//    NSLog(@"%@",mStr);
}

+ (void)stopSaveAndClean {
    [SMCallTrace stop];
    [SMCallTrace save];
    smClearCallRecords();
}

+ (void)appendRecord:(SMCallTraceTimeCostModel *)cost to:(NSMutableString *)mStr {
//    [mStr appendFormat:@"%@\n path%@\n",[cost des],cost.path];
    if (cost.subCosts.count < 1) {
        cost.lastCall = YES;
        //记录到数据库中
        [[SMLagDB shareInstance] addWithClsCallModel:cost];
    } else {
        for (SMCallTraceTimeCostModel *model in cost.subCosts) {
            if ([model.className isEqualToString:@"SMCallTrace"]) {
                break;
            }
            //记录方法的子方法的路径
            model.path = [NSString stringWithFormat:@"%@ - [%@ %@]",cost.path,model.className,model.methodName];
            [self appendRecord:model to:mStr];
        }
    }
    
}
+ (NSArray<SMCallTraceTimeCostModel *>*)loadRecords {
    
    // return [self loadCallRecords];
    
    // 获得前序序列（深度优先遍历）
    NSMutableArray<SMCallTraceTimeCostModel *> *arr = [NSMutableArray new];
    int num = 0;
    smCallRecord *records = smGetCallRecords(&num);
    for (int i = 0; i < num; i++) {
        smCallRecord *rd = &records[i];
        SMCallTraceTimeCostModel *model = [SMCallTraceTimeCostModel new];
        model.className = NSStringFromClass(rd->cls);
        model.methodName = NSStringFromSelector(rd->sel);
        model.isClassMethod = class_isMetaClass(rd->cls);
        model.timeCost = (double)rd->time / 1000000.0; // s 
        model.callDepth = rd->depth;
        // NSLog(@"%@-%@",model.methodName,@(model.callDepth));
        [arr addObject:model];
    }
    // 生成方法调用树
    NSUInteger count = arr.count;
    for (NSUInteger i = 0; i < count; i++) {
        SMCallTraceTimeCostModel *model = arr[i];
        if (model.callDepth > 0) {
            [arr removeObjectAtIndex:i];
            //Todo:不需要循环，直接设置下一个，然后判断好边界就行
            for (NSUInteger j = i; j < count - 1; j++) {
                //下一个深度小的话就开始将后面的递归的往 sub array 里添加
                if (arr[j].callDepth + 1 == model.callDepth) {
                    [arr[j].subCosts insertObject:model atIndex:0];
                }
            }
            i--;
            count--;
        }
    }
    return arr;
}

//+ (NSArray<SMCallTraceTimeCostModel *>*)loadCallRecords {
//    // 获得前序序列（深度优先遍历）
//    NSMutableArray<SMCallTraceTimeCostModel *> *arr = [NSMutableArray new];
//    int num = 0;
//    smCallRecord *records = smGetCallRecords(&num);
//
//    if (0 == num){
//        return arr;
//    }
//
//    NSMutableArray *rootArray = [NSMutableArray new];
//    smCallRecord *rd = &records[num-1];
//    NSInteger rootDepth = rd->depth;
//
//    for (int i = num-1; i >= 0 ; i--) {
//        smCallRecord *rd = &records[i];
//        SMCallTraceTimeCostModel *model = [SMCallTraceTimeCostModel new];
//        model.className = NSStringFromClass(rd->cls);
//        model.methodName = NSStringFromSelector(rd->sel);
//        model.isClassMethod = class_isMetaClass(rd->cls);
//        model.timeCost = (double)rd->time / 1000000.0; // s
//        model.callDepth = rd->depth;
//        model.index = i;
//        NSLog(@"%@-%@",model.methodName,@(model.callDepth));
//        [arr addObject:model];
//        if (rootDepth == model.callDepth) {
//            [rootArray addObject:model];
//        }
//    }
//    // 计算各个栈的范围
//    NSInteger rootCount = rootArray.count;
//    NSMutableArray *rangeArray = [NSMutableArray new];
//
//    if (rootCount <= 1 ) {
//        NSRange range = NSMakeRange(0, arr.count);
//        NSValue *value = [NSValue valueWithRange:range];
//        [rangeArray addObject:value];
//    }
//    else{
//        for (int i = 0; i < rootCount-1; i++) {
//            SMCallTraceTimeCostModel *model = rootArray[i];
//            SMCallTraceTimeCostModel *nextModel = rootArray[i+1];
//            NSInteger lengh = nextModel.index - model.index;
//            NSRange range = NSMakeRange(model.index, lengh);
//            NSValue *value = [NSValue valueWithRange:range];
//            [rangeArray addObject:value];
//            if (i == (rootCount-2)) {
//                NSInteger lengh = num - model.index;
//                NSRange range = NSMakeRange(model.index, lengh);
//                NSValue *value = [NSValue valueWithRange:range];
//                [rangeArray addObject:value];
//            }
//        }
//    }
//
//
//    [rootArray removeAllObjects];
//    for (NSValue *value in rootArray) {
//        NSRange range = [value rangeValue];
//        SMCallTraceTimeCostModel *rootModel = [self createTreeWithCallArray:arr range:range];
//        [rootArray addObject:rootModel];
//    }
//}
//
//+ (SMCallTraceTimeCostModel *)createTreeWithCallArray:(NSArray<SMCallTraceTimeCostModel *> *)callArray
//                                                           range:(NSRange)range{
//    NSInteger allNodeCount = callArray.count;
//    if (allNodeCount <= (rootIndex+1)) {
//        return callArray;
//    }
//
//    SMCallTraceTimeCostModel *rootNode = callArray[rootIndex];
//    NSInteger lastRootIndex = -1;
//
//    // 第一个树的
//    for (NSInteger i = rootIndex; i < allNodeCount-1; i++) {
//        SMCallTraceTimeCostModel *currentNode = callArray[i];
//        if (currentNode.callDepth >= 0) {
//            // 查找叶子节点
//            for (NSUInteger j = i+1; j < allNodeCount-1; j++) {
//                SMCallTraceTimeCostModel *successorNode = callArray[j];
//                //当前 currentNode 的叶子节点已经查找完毕，结束此次查找
//                if(currentNode.callDepth <= successorNode.callDepth){
//                    break;
//                }
//                if ((successorNode.callDepth + 1) == currentNode.callDepth) {
//                    [currentNode.subCosts insertObject:successorNode atIndex:0];
//                }
//            }
//        }
//        // 说明有多个树
//        if (rootIndex != i && rootNode.callDepth == currentNode.callDepth) {
//            lastRootIndex = i;
//            break;
//        }
//    }
//
//    // 生成下一个树
//    if (-1 != lastRootIndex) {
//        NSArray *lastArray = [self createTreeWithCallArray:callArray rootIndex:lastRootIndex];
//        NSMutableArray *rootArray = [[NSMutableArray alloc] init];
//        [rootArray addObject:rootNode];
//        if (lastArray.count>0) {
//            [rootArray addObjectsFromArray:lastArray];
//        }
//        return [rootArray copy];
//    }
//    return @[rootNode];
//}


@end
