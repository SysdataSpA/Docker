//
//  NSObject+DownloadManager.m
//  TurismoFVG
//
//  Created by Davide Ramo on 14/04/14.
//
//

#import "NSObject+DownloadManager.h"
#import "NSString+Hashing.h"
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
