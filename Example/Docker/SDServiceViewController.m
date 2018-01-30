//
//  SDServiceViewController.m
//  Docker
//
//  Created by Francesco Ceravolo on 11/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "SDServiceViewController.h"
#import "MyServiceManager.h"
#import "SDServiceExample.h"
#import "SDServiceViewCell.h"

@interface SDServiceViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray<MTLUser*>* users;

@end

@implementation SDServiceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    __weak typeof (self) weakSelf = self;
    [[MyServiceManager sharedServiceManager] callServiceForNumUsers:@25 withCompletion:^(SDServiceExampleResponse* response) {
        weakSelf.users = response.users;
        [weakSelf.tableView reloadData];
        
    } failure:^(SDServiceExampleError* error) {
        NSString* message = [NSString stringWithFormat:@"ErrorMessage = %@\nTechnicalMessage = %@\nHTTP status code = %d\nTechnical error code = %d", error.errorMessage, error.technicalErrorMessage, error.httpStatusCode, error.technicalErrorCode];
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:nil]];
        [weakSelf presentViewController:alert animated:YES completion:nil];
            
    }];
}

#pragma mark UITableView

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.users.count;
}

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    SDServiceViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    MTLUser* user = [self.users objectAtIndex:indexPath.row];
    cell.label.text = [NSString stringWithFormat:@"%@ %@", user.firstName, user.lastName];
    //[cell.downloadImageView setImageWithURLString:user.imageUrl];
    return cell;
}


@end
