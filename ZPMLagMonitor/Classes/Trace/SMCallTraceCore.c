//
//  SMCallTraceCore.c
//  DecoupleDemo
//
//  Created by DaiMing on 2017/7/16.
//  Copyright © 2017年 Starming. All rights reserved.
//

#include "SMCallTraceCore.h"

// __aarch64__ arm64 架构又分为 2 种执行状态：AArch64 Application Level 和 AArch32 Application Level
#if __arm64__
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <pthread.h>

#include "fishhook.h"

static bool _call_record_enabled = true;    // 标记是否进行方法监听
static uint64_t _min_time_cost = 1000;      // 监听最小时间（ us ）
static int _max_call_depth = 3;             // 方法监听最大深度
static smCallRecord *_smCallRecords;        // 记录监听数据
static int _smRecordNum;                    // 记录 _smCallRecords 数量
static int _smRecordAlloc;                  // 记录 _smCallRecords 已分配空间
static pthread_key_t _thread_key;           // 绑定到线层数据的 key
__unused static id (*orig_objc_msgSend)(id, SEL, ...);


#pragma mark - 函数声明

static void release_thread_call_stack(void *ptr);               // 释放 _thread_key 数据回调

__attribute__((__naked__)) static void hook_Objc_msgSend(void); // objc_msgSend 新实现

#endif


#pragma mark - Public

/// 开始监听并进行 objc_msgSend 实现替换
void smCallTraceStart(void) {
#if __arm64__
    _call_record_enabled = true;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_key_create(&_thread_key, &release_thread_call_stack);
        rebind_symbols((struct rebinding[6]){
            {"objc_msgSend", (void *)hook_Objc_msgSend, (void **)&orig_objc_msgSend},
        }, 1);
    });
#endif
}

/// 停止监听
void smCallTraceStop(void) {
#if __arm64__
    _call_record_enabled = false;
#endif
}

/// 开始监听并设置最小耗时
/// @param us 最小耗时 单位纳秒 us，默认 1000 us
void smCallConfigMinTime(uint64_t us) {
#if __arm64__
    _min_time_cost = us;
#endif
}

/// 开始监听并设置栈最大调用深度
/// @param depth 栈最大调用深度，默认 3
void smCallConfigMaxDepth(int depth) {
#if __arm64__
    _max_call_depth = depth;
#endif
}

/// 回去方法耗时数据
/// @param num 数据条数
smCallRecord *smGetCallRecords(int *num) {
#if __arm64__
    if (num) {
        *num = _smRecordNum;
    }
    return _smCallRecords;
#else
    if (num) {
        *num = 0;
    }
    return NULL;
#endif
}

/// 清空监听数据
void smClearCallRecords(void) {
#if __arm64__
    if (_smCallRecords) {
        free(_smCallRecords);
        _smCallRecords = NULL;
    }
    _smRecordNum = 0;
#endif
}


#pragma mark - Record

// arm64架构又分为2种执行状态： AArch64 Application Level 和 AArch32 Application Level
#if __arm64__

typedef struct {
    id self;            // 通过 object_getClass 能够得到 Class 再通过 NSStringFromClass 能够得到类名
    Class cls;
    SEL cmd;            // 通过 NSStringFromSelector 方法能够得到方法名
    uint64_t time;      // us
    uintptr_t lr;       // link register
} thread_call_record;

typedef struct {
    thread_call_record *stack;
    int allocated_length;
    int index;
    bool is_main_thread;
} thread_call_stack;

static inline thread_call_stack * get_thread_call_stack() {
    thread_call_stack *cs = (thread_call_stack *)pthread_getspecific(_thread_key);
    if (cs == NULL) {
        cs = (thread_call_stack *)malloc(sizeof(thread_call_stack));
        cs->stack = (thread_call_record *)calloc(128, sizeof(thread_call_record));
        cs->allocated_length = 64;
        cs->index = -1;
        cs->is_main_thread = pthread_main_np();
        pthread_setspecific(_thread_key, cs);
    }
    return cs;
}

static void release_thread_call_stack(void *ptr) {
    thread_call_stack *cs = (thread_call_stack *)ptr;
    if (!cs) return;
    if (cs->stack) free(cs->stack);
    free(cs);
}

static inline void push_call_record(id _self, Class _cls, SEL _cmd, uintptr_t lr) {
    thread_call_stack *cs = get_thread_call_stack();
    if (cs) {
        int nextIndex = (++cs->index);
        if (nextIndex >= cs->allocated_length) {
            cs->allocated_length += 64;
            cs->stack = (thread_call_record *)realloc(cs->stack, cs->allocated_length * sizeof(thread_call_record));
        }
        thread_call_record *newRecord = &cs->stack[nextIndex];
        newRecord->self = _self;
        newRecord->cls = _cls;
        newRecord->cmd = _cmd;
        newRecord->lr = lr;
        if (cs->is_main_thread && _call_record_enabled) {
            struct timeval now;
            gettimeofday(&now, NULL);
            newRecord->time = (now.tv_sec % 100) * 1000000 + now.tv_usec;
        }
    }
}

static inline uintptr_t pop_call_record() {
    thread_call_stack *cs = get_thread_call_stack();
    int curIndex = cs->index;
    int nextIndex = cs->index--;
    thread_call_record *pRecord = &cs->stack[nextIndex];
    
    if (cs->is_main_thread && _call_record_enabled) {
        struct timeval now;
        gettimeofday(&now, NULL);
        uint64_t time = (now.tv_sec % 100) * 1000000 + now.tv_usec;
        if (time < pRecord->time) {
            time += 100 * 1000000;
        }
        uint64_t cost = time - pRecord->time;
        if (cost > _min_time_cost && cs->index < _max_call_depth) {
            if (!_smCallRecords) {
                _smRecordAlloc = 1024;
                _smCallRecords = malloc(sizeof(smCallRecord) * _smRecordAlloc);
            }
            _smRecordNum++;
            if (_smRecordNum >= _smRecordAlloc) {
                _smRecordAlloc += 1024;
                _smCallRecords = realloc(_smCallRecords, sizeof(smCallRecord) * _smRecordAlloc);
            }
            smCallRecord *log = &_smCallRecords[_smRecordNum - 1];
            log->cls = pRecord->cls;
            log->depth = curIndex;
            log->sel = pRecord->cmd;
            log->time = cost;
        }
    }
    return pRecord->lr;
}

void before_objc_msgSend(id self, SEL _cmd, uintptr_t lr) {
    push_call_record(self, object_getClass(self), _cmd, lr);
}

// 返回 lr 的值
uintptr_t after_objc_msgSend() {
    return pop_call_record();
}


#define call(b, value) \
__asm volatile ("stp x8, x9, [sp, #-16]!\n"); \
__asm volatile ("mov x12, %0\n" :: "r"(value)); \
__asm volatile ("ldp x8, x9, [sp], #16\n"); \
__asm volatile (#b " x12\n");

#define save() \
__asm volatile ( \
"stp x8, x9, [sp, #-16]!\n" \
"stp x6, x7, [sp, #-16]!\n" \
"stp x4, x5, [sp, #-16]!\n" \
"stp x2, x3, [sp, #-16]!\n" \
"stp x0, x1, [sp, #-16]!\n");

#define load() \
__asm volatile ( \
"ldp x0, x1, [sp], #16\n" \
"ldp x2, x3, [sp], #16\n" \
"ldp x4, x5, [sp], #16\n" \
"ldp x6, x7, [sp], #16\n" \
"ldp x8, x9, [sp], #16\n" );

#define link(b, value) \
__asm volatile ("stp x8, lr, [sp, #-16]!\n"); \
__asm volatile ("sub sp, sp, #16\n"); \
call(b, value); \
__asm volatile ("add sp, sp, #16\n"); \
__asm volatile ("ldp x8, lr, [sp], #16\n");

#define ret() __asm volatile ("ret\n");

// 编译器不会生成入口代码和退出代码，写naked函数的时候要分外小心。进入函数代码时，父函数仅仅会将参数和返回地址压栈
__attribute__((__naked__)) static void hook_Objc_msgSend() {
    // Save parameters.
    save()
    
    __asm volatile ("mov x2, lr\n");
    __asm volatile ("mov x3, x4\n");
    
    // Call our before_objc_msgSend.
    call(blr, &before_objc_msgSend)
    
    // Load parameters.
    load()
    
    // Call through to the original objc_msgSend.
    call(blr, orig_objc_msgSend)
    
    // Save original objc_msgSend return value.
    save()
    
    // Call our after_objc_msgSend.
    call(blr, &after_objc_msgSend)
    
    // restore lr
    __asm volatile ("mov lr, x0\n");
    
    // Load original objc_msgSend return value.
    load()
    
    // return
    ret()
}

#endif
