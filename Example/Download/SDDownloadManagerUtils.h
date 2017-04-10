//
//  SDDownloadManagerUtils.h
//  SyncManager
//
//  Created by Francesco Ceravolo on 07/04/17.
//  Copyright © 2017 Francesco Ceravolo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SDDownloadManagerUtils : NSObject


+ (void) exportCreationDatesPlistForFilesContentInDirectoryAtPath:(NSString*)directoryPath;

+ (void) copyResourcesFromBundleFolderPath:(NSString*)bundleFolderPath inFileSystemPath:(NSString*)fileSystemFolderPath;


@end
