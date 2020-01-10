//
//  SMCallTraceCore.h
//  DecoupleDemo
//
//  Created by DaiMing on 2017/7/16.
//  Copyright © 2017年 Starming. All rights reserved.
//

#ifndef SMCallTraceCore_h
#define SMCallTraceCore_h

#include <stdio.h>
#include <objc/objc.h>

typedef struct {
    __unsafe_unretained Class cls;
    SEL sel;
    uint64_t time; // us (1/1000 ms)
    int depth;
} smCallRecord;


/// 开始监听并进行 objc_msgSend 实现替换
extern void smCallTraceStart(void);

/// 停止监听
extern void smCallTraceStop(void);

/// 开始监听并设置最小耗时
/// @param us 最小耗时 单位纳秒 us，默认 1000 us
extern void smCallConfigMinTime(uint64_t us);

/// 开始监听并设置栈最大调用深度
/// @param depth 栈最大调用深度，默认 3
extern void smCallConfigMaxDepth(int depth);

/// 回去方法耗时数据
/// @param num 数据条数
extern smCallRecord *smGetCallRecords(int *num);

/// 清空监听数据
extern void smClearCallRecords(void);



#endif /* SMCallTraceCore_h */
