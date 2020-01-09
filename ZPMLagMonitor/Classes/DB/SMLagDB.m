//
//  SMLagDB.m
//  DecoupleDemo
//
//  Created by DaiMing on 2017/8/3.
//  Copyright © 2017年 Starming. All rights reserved.
//

#import "SMLagDB.h"


@interface SMLagDB()

@property (nonatomic, copy) NSString *clsCallDBPath;
@property (nonatomic, strong) FMDatabaseQueue *dbQueue;

@end

@implementation SMLagDB

+ (SMLagDB *)shareInstance {
    static SMLagDB *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SMLagDB alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _clsCallDBPath = [PATH_OF_DOCUMENT stringByAppendingPathComponent:@"clsCall.sqlite"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:_clsCallDBPath] == NO) {
            FMDatabase *db = [FMDatabase databaseWithPath:_clsCallDBPath];
            if ([db open]) {
                /* clsCall 表记录方法读取频次的表
                 cid: 主id
                 fid: 父id 暂时不用
                 cls: 类名
                 mtd: 方法名
                 path: 完整路径标识
                 timecost: 方法消耗时长
                 calldepth: 层级
                 frequency: 调用次数
                 lastcall: 是否是最后一个 call
                 */
                NSString *createSql = @"create table clscall (cid INTEGER PRIMARY KEY AUTOINCREMENT  NOT NULL, fid integer, cls text, mtd text, path text, timecost double, calldepth integer, frequency integer, lastcall integer)";
                [db executeUpdate:createSql];
                
                /* stack 表记录
                 sid: id
                 stackcontent: 堆栈内容
                 insertdate: 日期
                 */
                NSString *createStackSql = @"create table stack (sid INTEGER PRIMARY KEY AUTOINCREMENT  NOT NULL, stackcontent text,isstuck integer, insertdate double)";
                [db executeUpdate:createStackSql];
            }
        }
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:_clsCallDBPath];
    }
    return self;
}

#pragma mark - 卡顿和CPU超标堆栈

// 添加 Stack 记录
- (void)increaseWithStackModel:(SMCallStackModel *)model {
    [self.dbQueue inDatabase:^(FMDatabase *db){
        if ([db open]) {
            NSNumber *stuck = @0;
            if (model.isStuck) {
                stuck = @1;
            }
            [db executeUpdate:@"insert into stack (stackcontent, isstuck, insertdate) values (?, ?, ?)",model.stackStr, stuck, [NSDate date]];
            [db close];
        }
    }];
}

// 分页查询 Stack 数据
- (void)selectStackWithPage:(NSUInteger)page completion:(void (^ __nullable)(NSArray *array))completion {
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableArray *arr = [NSMutableArray array];
        if ([db open]) {
            FMResultSet *rs = [db executeQuery:@"select * from stack order by sid desc limit ?, 50",@(page * 50)];
            while ([rs next]) {
                SMCallStackModel *model = [[SMCallStackModel alloc] init];
                model.stackStr = [rs stringForColumn:@"stackcontent"];
                model.isStuck = [rs boolForColumn:@"isstuck"];
                model.dateString = [rs doubleForColumn:@"insertdate"];
                [arr addObject:model];
            }
            [db close];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion([arr copy]);
            }
        });
    }];
}

// 清空 Stack 数据
- (void)clearStackData {
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if ([db open]) {
            [db executeUpdate:@"delete from stack"];
            [db close];
        }
    }];
}

#pragma mark - ClsCall方法调用频次

// 添加 Trace 记录
- (void)addWithClsCallModel:(SMCallTraceTimeCostModel *)model {
    if ([model.methodName isEqualToString:@"clsCallInsertToViewWillAppear"] || [model.methodName isEqualToString:@"clsCallInsertToViewWillDisappear"]) {
        return;
    }
    [self.dbQueue inDatabase:^(FMDatabase *db){
        if ([db open]) {
            //添加白名单
            FMResultSet *rsl = [db executeQuery:@"select cid,frequency from clscall where path = ?", model.path];
            if ([rsl next]) {
                //有相同路径就更新路径访问频率
                int fq = [rsl intForColumn:@"frequency"] + 1;
                int cid = [rsl intForColumn:@"cid"];
                [db executeUpdate:@"update clscall set frequency = ? where cid = ?", @(fq), @(cid)];
            } else {
                //没有就添加一条记录
                NSNumber *lastCall = @0;
                if (model.lastCall) {
                    lastCall = @1;
                }
                [db executeUpdate:@"insert into clscall (cls, mtd, path, timecost, calldepth, frequency, lastcall) values (?, ?, ?, ?, ?, ?, ?)", model.className, model.methodName, model.path, @(model.timeCost), @(model.callDepth), @1, lastCall];
            }
            [db close];
        }
    }];
}

// 分页查询 Trace 数据
- (void)selectClsCallWithPage:(NSUInteger)page completion:(void (^ __nullable)(NSArray *array))completion {
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableArray *arr = [NSMutableArray array];
        if ([db open]) {
            FMResultSet *rs = [db executeQuery:@"select * from clscall where lastcall=? order by frequency desc limit ?, 50",@1, @(page * 50)];
            while ([rs next]) {
                SMCallTraceTimeCostModel *model = [self clsCallModelFromResultSet:rs];
                [arr addObject:model];
            }
            [db close];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion([arr copy]);
            }
        });
    }];
}

// 清除 Trace 数据
- (void)clearClsCallData {
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if ([db open]) {
            [db executeUpdate:@"delete from clscall"];
            [db close];
        }
    }];
}

//结果封装成 model
- (SMCallTraceTimeCostModel *)clsCallModelFromResultSet:(FMResultSet *)rs {
    SMCallTraceTimeCostModel *model = [[SMCallTraceTimeCostModel alloc] init];
    model.className = [rs stringForColumn:@"cls"];
    model.methodName = [rs stringForColumn:@"mtd"];
    model.path = [rs stringForColumn:@"path"];
    model.timeCost = [rs doubleForColumn:@"timecost"];
    model.callDepth = [rs intForColumn:@"calldepth"];
    model.frequency = [rs intForColumn:@"frequency"];
    model.lastCall = [rs boolForColumn:@"lastcall"];
    return model;
}


@end
