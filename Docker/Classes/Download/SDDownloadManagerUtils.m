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

#import "SDDownloadManagerUtils.h"
#import "SDFileManager.h"
#import "SDDockerLogger.h"

@implementation SDDownloadManagerUtils

+ (void) exportCreationDatesPlistForFilesContentInDirectoryAtPath:(NSString*)directoryPath
{
    NSArray* directoryContents = [SDFileManager getFilesContentInDirectoryNamed:directoryPath];
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    for (NSString* fileName in directoryContents)
    {
        NSString* filePath = [directoryPath stringByAppendingPathComponent:fileName];
        SDFileInfo* fileInfo = [SDFileManager getInfoAboutFileAtPath:filePath];
        if (fileInfo.modificationDateOnServer)
        {
            dictionary[fileName] = fileInfo.modificationDateOnServer;
        }
    }
    
    NSString* plistUrl = [directoryPath stringByAppendingPathComponent:@"ResourceInfos.plist"];
    [dictionary writeToFile:plistUrl atomically:YES];
    
    SDLogInfo(@"Exported infos of files in folder %@ on plist file %@", directoryPath, plistUrl);
}

+ (void) copyResourcesFromBundleFolderPath:(NSString*)bundleFolderPath inFileSystemPath:(NSString*)fileSystemFolderPath
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSString* fileInfosPath = [bundleFolderPath stringByAppendingPathComponent:@"ResourceInfos.plist"];
    NSDictionary* dictionaryInfos = [NSDictionary dictionaryWithContentsOfFile:fileInfosPath];
    
    NSArray* directoryContents = [SDFileManager getFilesContentInDirectoryNamed:bundleFolderPath];
    
    for (NSString* fileName in directoryContents)
    {
        NSString* fileBundlePath = [bundleFolderPath stringByAppendingPathComponent:fileName];
        NSString* fileSystemPath = [fileSystemFolderPath stringByAppendingPathComponent:fileName];
        NSError* error;
        [fileManager copyItemAtPath:fileBundlePath toPath:fileSystemPath error:&error];
        if (error)
        {
            SDLogError(@"Error copying bundle resources at path %@ to filesystem path %@\nError: %@", fileBundlePath, fileSystemPath, error.localizedDescription);
            continue;
        }
        
        // override creation date
        NSDate* creationDate = dictionaryInfos[fileName];
        if (creationDate)
        {
            NSError* error = nil;
            NSMutableDictionary* attrs = [[[NSFileManager defaultManager] attributesOfItemAtPath:fileSystemPath error:&error] mutableCopy];
            if (!error)
            {
                attrs[NSFileCreationDate] = creationDate;
                [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:fileSystemPath error:NULL];
            }
        }
    }
}


@end
