//
//  SDBundleExportViewController.m
//  Docker
//
//  Created by Francesco Ceravolo on 04/05/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "SDBundleExportViewController.h"
#import <Docker/SDDownloadManager.h>
#import <Docker/SDDownloadManagerUtils.h>

@interface SDBundleExportViewController ()

@end

@implementation SDBundleExportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Actions

- (IBAction)createPlistFileTapped:(UIButton *)sender
{
    NSString* path = [SDDownloadManager sharedManager].fileSystemPath;
    [SDDownloadManagerUtils exportCreationDatesPlistForFilesContentInDirectoryAtPath:path];
}

- (IBAction)copyFilesTapped:(UIButton *)sender
{
    NSString* bundlePath = [[NSBundle mainBundle] pathForResource:@"resources_to_copy" ofType:@""];;
    NSString* fileSystemPath = [SDDownloadManager sharedManager].fileSystemPath;
    
    [SDDownloadManagerUtils copyResourcesFromBundleFolderPath:bundlePath inFileSystemPath:fileSystemPath];
}



@end
