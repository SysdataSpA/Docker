//
//  SDServiceViewController.m
//  Docker
//
//  Created by Francesco Ceravolo on 11/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "SDServiceViewController.h"
#import "MyServiceManager.h"

@interface SDServiceViewController ()

@end

@implementation SDServiceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[MyServiceManager sharedServiceManager] callServiceForNumUsers:@25 withCompletion:^(id<SDServiceGenericResponseProtocol> response) {
        
    } failure:^(id<SDServiceGenericErrorProtocol> error) {
        
    }];
}




@end
