//
//  SDImageViewController.m
//  Docker
//
//  Created by Francesco Ceravolo on 10/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "SDImageViewController.h"
#import "SDTableViewCell.h"

@interface SDImageViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSArray<NSString*>* imageUrls;

@end

@implementation SDImageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.imageUrls = @[
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898"
                      ];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView reloadData];
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.imageUrls.count;
}

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    SDTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    NSString* urlString = [self.imageUrls objectAtIndex:indexPath.row];
    
    //cell.downloadImageView.showActivityIndicatorWhileLoading = YES;
    //cell.downloadImageView.showLocalImageBeforeCheckingValidity = YES;
    //cell.downloadImageView.placeHolderImage = nil;
    //cell.downloadImageView.downloadOptions = DownloadOperationOptionForceDownload;
    
    //[cell.downloadImageView setImageWithURLString:urlString completion:^(NSString* urlString, UIImage* image, DownloadOperationResultType resultType) {}];
    return cell;
}

@end
