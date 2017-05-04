// Copyright 2017 Sysdata S.p.A.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

@interface SDDownloadManagerUtils : NSObject

/**
 *   This method should be used only to create the plist file that keep modified-date for all downloaded files.
 *   The plist files is required if your DownloadManager use HEAD request to check updates also for downloaded files (settings useHeadRequestToCheckUpdates = YES).
 *
 *   This method should be invoked ONLY before you want to create your seed resources. The generated plist files should be included in your bundle seed folder within your seed resources.
 *
 *   @param directoryPath       folder path that contains files which you want to export creation and modified infos (tipically is the fileSystemPath of your DownloadManager)
 *
 */
+ (void) exportCreationDatesPlistForFilesContentInDirectoryAtPath:(NSString*)directoryPath;



/**
 *   This method should be used to copy resources from bundle to file system resources, avoiding your DownloadManager to have seed resources and not requiring first download of them.
 *
 *   To work correctly in the bundle folder should be, in addition of files, the plist file generated by exportCreationDatesPlistForFilesContentInDirectoryAtPath: method. The plist file contains the created and modified dates of each file that will be set during copy of files.
 
 *   You can copy files from bundle to file system or you can set your DownloadManager to get seed files directly from bundle (setting useBundle = YES and bundlePath = <your path>). If you decide to copy files:
 *   PROS:
 *        - you can check for next updates of the same file (uploaded at the same url)
 *   CONS:
 *        - your app have twice same files, so each file will weight double
 
 *   @param bundleFolderPath       folder path in bundle that contains files which you want to copy into file system (tipically is the bundle folder of your seed resources)
 *   @param fileSystemFolderPath   folder path into file system where copy files (tipically is the fileSystemPath of your DownloadManager)
 */
+ (void) copyResourcesFromBundleFolderPath:(NSString*)bundleFolderPath inFileSystemPath:(NSString*)fileSystemFolderPath;


@end
