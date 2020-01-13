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
    
    
    [SMCallTrace start];
    
    [self test1];
    
    //[self test10];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [SMCallTrace stopSaveAndClean];
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

@end
