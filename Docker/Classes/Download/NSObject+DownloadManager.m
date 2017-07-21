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

#import "NSObject+DownloadManager.h"
#import "NSString+Docker.h"
#import "SDDownloadManager.h"

@implementation NSObject (DownloadManager)

- (NSString*) localResourcePathForKeyPath:(NSString*)keyPath
{
    return [NSObject localResourcePathForUrlString:[self valueForKeyPath:keyPath]];
}

+ (NSString*) localResourcePathForUrlString:(NSString*)urlString
{
    NSString* hashMD5 = [urlString MD5String];

    if (hashMD5)
    {
        NSString* path = [[SDDownloadManager sharedManager].fileSystemPath stringByAppendingPathComponent:hashMD5];
        return path;
    }
    else
    {
        return nil;
    }
}

@end
