//
//  SMStackViewController.m
//  DecoupleDemo
//
//  Created by DaiMing on 2017/8/17.
//  Copyright © 2017年 Starming. All rights reserved.
//

#import "SMStackViewController.h"
#import "MJRefresh.h"
#import "SMStackCell.h"
#import "SMLagDB.h"

static NSString *smStackCellIdentifier = @"smStackCell";

@interface SMStackViewController ()<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) NSMutableArray *listData;
@property (nonatomic, strong) UITableView *tbView;
@property (nonatomic) NSUInteger page;
@property (nonatomic, strong) UIBarButtonItem *clearBarButtonItem;

@end

@implementation SMStackViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.page = 0;
    [self selectItems];
    [self.tbView registerClass:[UITableViewCell class] forCellReuseIdentifier:smStackCellIdentifier];
    [self.view addSubview:self.tbView];
    self.navigationItem.rightBarButtonItems = @[self.clearBarButtonItem];
}

- (void)selectItems {
    __weak typeof(self) weakSelf = self;
    [[SMLagDB shareInstance] selectStackWithPage:self.page completion:^(NSArray * _Nonnull array) {
        __strong typeof(weakSelf) strongSelf = weakSelf; if(!strongSelf) return;
        strongSelf.tbView.mj_footer.hidden = array.count < 50; // 每页50条，如果小于50说明没有更多数据了
        if (array.count > 0) {
            if (strongSelf.listData.count > 0) {
                //加载更多
                [strongSelf.listData addObjectsFromArray:array];
            } else {
                //进入时加载
                strongSelf.listData = [array mutableCopy];
            }
            [strongSelf.tbView reloadData];
            strongSelf.page += 1;
        }
        [strongSelf.tbView.mj_footer endRefreshingWithNoMoreData];
        [strongSelf.tbView.mj_footer endRefreshing];
    }];
}

#pragma mark - UITableView Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.listData.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    SMCallStackModel *model = self.listData[indexPath.row];
    CGRect frame = [model.stackStr boundingRectWithSize:CGSizeMake([UIScreen mainScreen].bounds.size.width - 10*2, 999) options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12]} context:nil];
    CGFloat height = 70.f + ceil(frame.size.height);
    return height > 400.f ? 400.f : height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:smStackCellIdentifier];
    cell.backgroundColor = [UIColor clearColor];
    cell.selected = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = [UIColor clearColor];
    
    SMStackCell *v = (SMStackCell *)[cell viewWithTag:231876];
    if (!v) {
        v = [[SMStackCell alloc] init];
        v.tag = 231876;
        if (cell) {
            [cell.contentView addSubview:v];
            v.frame = cell.contentView.frame;
        }
    }
    
    SMCallStackModel *model = self.listData[indexPath.row];
    [v updateWithModel:model];
    return cell;
}

#pragma mark - Getter
- (NSMutableArray *)listData {
    if (!_listData) {
        _listData = [NSMutableArray array];
    }
    return _listData;
}
- (UITableView *)tbView {
    if (!_tbView) {
        _tbView = [[UITableView alloc] initWithFrame:CGRectZero];
        _tbView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
        _tbView.dataSource = self;
        _tbView.delegate = self;
        _tbView.backgroundColor = [UIColor clearColor];
        _tbView.separatorStyle = UITableViewCellSelectionStyleNone;
        //mj
        _tbView.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingTarget:self refreshingAction:@selector(selectItems)];
        MJRefreshAutoNormalFooter *footer = (MJRefreshAutoNormalFooter *)_tbView.mj_footer;
        footer.stateLabel.font = [UIFont systemFontOfSize:12];
        footer.stateLabel.textColor = [UIColor lightGrayColor];
        [footer setTitle:@"上拉读取更多" forState:MJRefreshStateIdle];
        [footer setTitle:@"正在读取..." forState:MJRefreshStateRefreshing];
        [footer setTitle:@"已读取完毕" forState:MJRefreshStateNoMoreData];
    }
    return _tbView;
}

- (UIBarButtonItem *)clearBarButtonItem {
    if (!_clearBarButtonItem) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:@"清除" forState:UIControlStateNormal];
         btn.titleLabel.font = [UIFont systemFontOfSize:12.f weight:UIFontWeightBold];
        [btn addTarget:self action:@selector(btnClick) forControlEvents:UIControlEventTouchUpInside];
        _clearBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:btn];
    }
    return _clearBarButtonItem;
}

- (void)btnClick{
    __weak typeof(self) weakSelf = self;
    [[SMLagDB shareInstance] clearStackDataCompletion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf; if(!strongSelf) return;
        strongSelf.page = 1;
        [strongSelf.listData removeAllObjects];
        [strongSelf.tbView reloadData];
    }];
}

@end
