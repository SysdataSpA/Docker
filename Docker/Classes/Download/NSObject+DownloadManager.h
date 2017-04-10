//
//  NSObject+DownloadManager.h
//  TurismoFVG
//
//  Created by Davide Ramo on 14/04/14.
//
//

#import <Foundation/Foundation.h>

@interface NSObject (DownloadManager)

- (NSString*) localResourcePathForKeyPath:(NSString*)keyPath;
+ (NSString*) localResourcePathForUrlString:(NSString*)urlString;

@end
