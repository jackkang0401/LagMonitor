//
//  ZPMViewController.m
//  ZPMLagMonitor
//
//  Created by yongshuai.kang on 01/06/2020.
//  Copyright (c) 2020 yongshuai.kang. All rights reserved.
//

#import "ZPMViewController.h"
#import "SMCallTrace.h"
#import "SMClsCallViewController.h"
#import "SMStackViewController.h"

@interface ZPMViewController ()

@end

@implementation ZPMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    
    
    

}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
}


- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
}

- (void)test1{
    for (int i = 0; i < 2; i++) {
        [self test2];
    }
}

- (void)test10{
    for (int i = 0; i < 2; i++) {
        [self test2];
    }
}

- (void)test2{
    for (int i = 0; i < 2; i++) {
        [self test3];
    }
}

- (void)test3{
    for (int i = 0; i < 100; i++) {
        NSLog(@"%@",@(i));
    }
}


- (IBAction)traceBtnClick:(id)sender {
    SMClsCallViewController *tVC = [[SMClsCallViewController alloc] init];
    [self.navigationController pushViewController:tVC animated:YES];
}

- (IBAction)stackBtnClick:(id)sender {
    SMStackViewController *sVC = [[SMStackViewController alloc] init];
    [self.navigationController pushViewController:sVC animated:YES];
}

- (IBAction)startAction:(UIButton *)btn {
    if (btn.isSelected) {
        [SMCallTrace stopSaveAndClean];
    }
    else{
        [SMCallTrace start];
    }
    btn.selected = !btn.isSelected;
}

- (IBAction)test1Action:(UIButton *)sender {
    [self test1];
}

- (IBAction)test2Action:(UIButton *)sender {
    [self test2];
}

- (IBAction)test3Action:(UIButton *)sender {
    [self test3];
}


@end
