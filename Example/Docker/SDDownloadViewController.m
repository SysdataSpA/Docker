//
//  SDDownloadViewController.m
//  Docker
//
//  Created by Francesco Ceravolo on 26/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "SDDownloadViewController.h"


@interface SDDownloadViewController ()

@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentOperationLabel;

@property (nonatomic, strong) NSArray<NSString*>* imageUrls;


@end

@implementation SDDownloadViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageUrls = @[
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898"
                       ];
}



#pragma mark Actions

- (IBAction)checkSizeTapped:(UIButton *)sender {
    __weak typeof (self) weakSelf = self;
    self.currentOperationLabel.text = @"Check size resources to download in progress...";
    
    [[SDDownloadManager sharedManager] countDownloadSizeForResourceAtUrls:self.imageUrls options:nil progress:^(long long totalSize, long numElementsToDownload) {
        weakSelf.sizeLabel.text = [NSString stringWithFormat:@"%d item to download. Total size %.2f MB", (int) numElementsToDownload, totalSize / (double)(1024*1024)];
    } completion:^(long long totalSize, long numElementsToDownload) {
        weakSelf.currentOperationLabel.text = @"Check size resources completed!!!";
    }];
    
}


- (IBAction)downloadAllCheckedTapped:(UIButton *)sender {
    
    self.currentOperationLabel.text = @"Download resources checked in progress...";
    
    __weak typeof (self) weakSelf = self;
    [[SDDownloadManager sharedManager] downloadAllElementsCheckedWithProgress:^(long long totalSizeExpected, long long sizeRemaining, long numElementsToDownloadExpected, long numElementsToDownloadRemaining) {
        weakSelf.sizeLabel.text = [NSString stringWithFormat:@"%ld / %ld\n%.2f / %.2f MB", numElementsToDownloadRemaining, numElementsToDownloadExpected, sizeRemaining / (double) (1024*1024), totalSizeExpected / (double)(1024*1024)];
    } completion:^(BOOL downloadCompleted) {
        weakSelf.currentOperationLabel.text = @"Download resources completed!!!";
    }];
}

- (IBAction)interruptTapped:(UIButton *)sender
{
    [[SDDownloadManager sharedManager] cancelAllDownloadRequests];
}

- (IBAction)deleteLocalFilesTapped:(UIButton *)sender
{
    [[SDDownloadManager sharedManager] purgeLocalFilesOlderThanNumDays:0];
}

@end
