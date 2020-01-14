//
//  SMCallTraceCore.c
//  DecoupleDemo
//
//  Created by DaiMing on 2017/7/16.
//  Copyright © 2017年 Starming. All rights reserved.
//

#include "SMCallTraceCore.h"

// __aarch64__ arm64 架构又分为 2 种执行状态：AArch64 Application Level 和 AArch32 Application Level
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)
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
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)
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
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)
    _call_record_enabled = false;
#endif
}

/// 开始监听并设置最小耗时
/// @param us 最小耗时 单位纳秒 us，默认 1000 us
void smCallConfigMinTime(uint64_t us) {
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)
    _min_time_cost = us;
#endif
}

/// 开始监听并设置栈最大调用深度
/// @param depth 栈最大调用深度，默认 3
void smCallConfigMaxDepth(int depth) {
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)
    _max_call_depth = depth;
#endif
}

/// 回去方法耗时数据
/// @param num 数据条数
smCallRecord *smGetCallRecords(int *num) {
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)
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
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)
    if (_smCallRecords) {
        free(_smCallRecords);
        _smCallRecords = NULL;
    }
    _smRecordNum = 0;
#endif
}


#pragma mark - Record

// arm64架构又分为2种执行状态： AArch64 Application Level 和 AArch32 Application Level
#if __arm64__  ||  (__x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC)

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

static inline uintptr_t push_call_record(id _self, Class _cls, SEL _cmd, uintptr_t lr) {
    thread_call_stack *cs = get_thread_call_stack();
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
    // 返回原始实现
    return (uintptr_t)orig_objc_msgSend;
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

uintptr_t before_objc_msgSend(id self, SEL _cmd, uintptr_t lr) {
    return push_call_record(self, object_getClass(self), _cmd, lr);
}

// 返回 lr 的值
uintptr_t after_objc_msgSend() {
    return pop_call_record();
}

#endif

#if __arm64__

#pragma mark - 64 位真机实现
__attribute__((__naked__)) static void hook_Objc_msgSend() {
    // save parameter registers: x0..x8, q0..q7
    __asm volatile (
                    "stp q0, q1, [sp, #-32]!\n"
                    "stp q2, q3, [sp, #-32]!\n"
                    "stp q4, q5, [sp, #-32]!\n"
                    "stp q6, q7, [sp, #-32]!\n"
                    "stp x0, x1, [sp, #-16]!\n"
                    "stp x2, x3, [sp, #-16]!\n"
                    "stp x4, x5, [sp, #-16]!\n"
                    "stp x6, x7, [sp, #-16]!\n"
                    "str x8,     [sp, #-16]!\n"
                    );

    __asm volatile (
                    "mov x2, lr\n"
                    "bl _before_objc_msgSend\n"
                    );

    // restore registers
    __asm volatile (
                    "ldr x8,     [sp], #16\n"
                    "ldp x6, x7, [sp], #16\n"
                    "ldp x4, x5, [sp], #16\n"
                    "ldp x2, x3, [sp], #16\n"
                    "ldp x0, x1, [sp], #16\n"
                    "ldp q6, q7, [sp], #32\n"
                    "ldp q4, q5, [sp], #32\n"
                    "ldp q2, q3, [sp], #32\n"
                    "ldp q0, q1, [sp], #32\n"
                    );

    // objc_msgSend
    __asm volatile ("mov x12, %0\n" :: "r"(orig_objc_msgSend));
    __asm volatile ("blr x12\n");

    // save parameter registers: x0..x8, q0..q7
    __asm volatile (
                    "stp q0, q1, [sp, #-32]!\n"
                    "stp q2, q3, [sp, #-32]!\n"
                    "stp q4, q5, [sp, #-32]!\n"
                    "stp q6, q7, [sp, #-32]!\n"
                    "stp x0, x1, [sp, #-16]!\n"
                    "stp x2, x3, [sp, #-16]!\n"
                    "stp x4, x5, [sp, #-16]!\n"
                    "stp x6, x7, [sp, #-16]!\n"
                    "str x8,     [sp, #-16]!\n"
                    );

    __asm volatile (
                    "bl _after_objc_msgSend\n"
                    "mov lr, x0\n"
                    );

    // restore registers
    __asm volatile (
                    "ldr x8,     [sp], #16\n"
                    "ldp x6, x7, [sp], #16\n"
                    "ldp x4, x5, [sp], #16\n"
                    "ldp x2, x3, [sp], #16\n"
                    "ldp x0, x1, [sp], #16\n"
                    "ldp q6, q7, [sp], #32\n"
                    "ldp q4, q5, [sp], #32\n"
                    "ldp q2, q3, [sp], #32\n"
                    "ldp q0, q1, [sp], #32\n"
                    );

    // return
    __asm volatile ("ret\n");
}

#endif

#if __x86_64__  &&  TARGET_OS_SIMULATOR  &&  !TARGET_OS_IOSMAC

#pragma mark - 64 位模拟器实现

/*
    栈基址指针 %rbp 始终指向当前函数调用开始时栈的位置，栈指针 %rsp 始终指向栈中最新的元素对应的
 位置， %rbp 和 %rsp 之间的元素被我们成为”栈帧”
 
    因为执行函数调用前会将调用者的下一条指令压入栈中，而被调用者函数内部因为有本地栈帧的定义又会将
 栈顶下移，所以在被调用者函数执行ret指令返回之前需要确保当前堆栈寄存器 %rsp 所指向的栈顶地址要和
 被调用函数执行前的栈顶地址保持一致，不然当ret指令执行时取出的调用者的下一条指令的值将是错误的，从
 而会产生崩溃异常
 */

__attribute__((__naked__)) static void hook_Objc_msgSend() {
    
//    __asm volatile (
//                    "pushq  %rbp\n"
//                    "movq   %rsp, %rbp\n"
//                    "subq   $0x88, %rsp\n"
//                    "movdqa %xmm0, -0x80(%rbp)\n"
//                    "pushq  %rax\n"
//                    "movdqa %xmm1, -0x70(%rbp)\n"
//                    "pushq  %rdi\n"
//                    "movdqa %xmm2, -0x60(%rbp)\n"
//                    "pushq  %rsi\n"
//                    "movdqa %xmm3, -0x50(%rbp)\n"
//                    "pushq  %rdx\n"
//                    "movdqa %xmm4, -0x40(%rbp)\n"
//                    "pushq  %rcx\n"
//                    "movdqa %xmm5, -0x30(%rbp)\n"
//                    "pushq  %r8\n"
//                    "movdqa %xmm6, -0x20(%rbp)\n"
//                    "pushq  %r9\n"
//                    "movdqa %xmm7, -0x10(%rbp)\n"
//                    );
//
//    __asm volatile (
//                    "movq       0x8(%rbp), %rdx\n"      // 返回地址
//                    "call       _before_objc_msgSend\n"
//                    "movq       %rax, %r11\n"
//                    );
//
//    __asm volatile (
//                    "movdqa -0x80(%rbp), %xmm0\n"
//                    "popq   %r9\n"
//                    "movdqa -0x70(%rbp), %xmm1\n"
//                    "popq   %r8\n"
//                    "movdqa -0x60(%rbp), %xmm2\n"
//                    "popq   %rcx\n"
//                    "movdqa -0x50(%rbp), %xmm3\n"
//                    "popq   %rdx\n"
//                    "movdqa -0x40(%rbp), %xmm4\n"
//                    "popq   %rsi\n"
//                    "movdqa -0x30(%rbp), %xmm5\n"
//                    "popq   %rdi\n"
//                    "movdqa -0x20(%rbp), %xmm6\n"
//                    "popq   %rax\n"
//                    "movdqa -0x10(%rbp), %xmm7\n"
//                    "testq  %r11, %r11\n"
//                    "leave\n"
//                    );
//
//    // objc_msgSend
//    __asm volatile ("addq   $0x8, %rsp\n");
//    __asm volatile ("call       *%r11\n");
    
    
    __asm volatile (
                    "subq       $(0x80+0x8), %rsp\n"
                    
                    "movdqa     %xmm0, (%rsp)\n"
                    "movdqa     %xmm1, 0x10(%rsp)\n"
                    "movdqa     %xmm2, 0x20(%rsp)\n"
                    "movdqa     %xmm3, 0x30(%rsp)\n"
                    "movdqa     %xmm4, 0x40(%rsp)\n"
                    "movdqa     %xmm5, 0x50(%rsp)\n"
                    "movdqa     %xmm6, 0x60(%rsp)\n"
                    "movdqa     %xmm7, 0x70(%rsp)\n"
                    "pushq      %rax\n"
                    "pushq      %r9\n"
                    "pushq      %r8\n"
                    "pushq      %rcx\n"
                    "pushq      %rdx\n"
                    "pushq      %rsi\n"
                    "pushq      %rdi\n"
                    "pushq      %rax\n"
                    );
    
    __asm volatile (
                    "call       _before_objc_msgSend\n"
                    "movq       %rax, %r10\n"
                    );

    __asm volatile (
                    "pop        %rax\n"
                    "pop        %rdi\n"
                    "pop        %rsi\n"
                    "pop        %rdx\n"
                    "pop        %rcx\n"
                    "pop        %r8\n"
                    "pop        %r9\n"
                    "pop        %rax\n"
                    "movdqa     (%rsp), %xmm0\n"
                    "movdqa     0x10(%rsp), %xmm1\n"
                    "movdqa     0x20(%rsp), %xmm2\n"
                    "movdqa     0x30(%rsp), %xmm3\n"
                    "movdqa     0x40(%rsp), %xmm4\n"
                    "movdqa     0x50(%rsp), %xmm5\n"
                    "movdqa     0x60(%rsp), %xmm6\n"
                    "movdqa     0x70(%rsp), %xmm7\n"
                    
                    "addq       $(16*8+8),  %rsp\n"
                    );

    // objc_msgSend
    __asm volatile ("jmpq       *%r10\n");
    //__asm volatile ("callq       *%0\n" :: "r"(orig_objc_msgSend));

    __asm volatile (
                    "pushq      %r10\n"
                    "push       %rbp\n"
                    "movq       %rsp, %rbp\n"
                    
                    "subq       $(0x80), %rsp\n"
                    "movdqa     %xmm0, -0x80(%rbp)\n"
                    "push       %rax\n"
                    "movdqa     %xmm1, -0x70(%rbp)\n"
                    "push       %rdi\n"
                    "movdqa     %xmm2, -0x60(%rbp)\n"
                    "push       %rsi\n"
                    "movdqa     %xmm3, -0x50(%rbp)\n"
                    "push       %rdx\n"
                    "movdqa     %xmm4, -0x40(%rbp)\n"
                    "push       %rcx\n"
                    "movdqa     %xmm5, -0x30(%rbp)\n"
                    "push       %r8\n"
                    "movdqa     %xmm6, -0x20(%rbp)\n"
                    "push       %r9\n"
                    "movdqa     %xmm7, -0x10(%rbp)\n"
                    
                    "pushq      0x8(%rbp)\n"
                    "movq       %rbp, %rax\n"
                    "addq       $8, %rax\n"
                    "pushq      %rax\n"
                    );

    __asm volatile (
                    "call       _after_objc_msgSend\n"
                    );
    
    __asm volatile (
                    "pop        %rax\n"
                    "pop        8(%rbp)\n"
                    
                    "movdqa     -0x80(%rbp), %xmm0\n"
                    "pop        %r9\n"
                    "movdqa     -0x70(%rbp), %xmm1\n"
                    "pop        %r8\n"
                    "movdqa     -0x60(%rbp), %xmm2\n"
                    "pop        %rcx\n"
                    "movdqa     -0x50(%rbp), %xmm3\n"
                    "pop        %rdx\n"
                    "movdqa     -0x40(%rbp), %xmm4\n"
                    "pop        %rsi\n"
                    "movdqa     -0x30(%rbp), %xmm5\n"
                    "pop        %rdi\n"
                    "movdqa     -0x20(%rbp), %xmm6\n"
                    "pop        %rax\n"
                    "movdqa     -0x10(%rbp), %xmm7\n"
                    
                    "leave\n"
                    "movq       %r10, (%rsp)\n"
                    );

    __asm volatile ("ret\n");
}

#endif
