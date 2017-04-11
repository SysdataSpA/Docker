//
//  SDServiceExample.m
//  Docker
//
//  Created by Francesco Ceravolo on 11/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "SDServiceExample.h"
#import "MyServiceManager.h"

@implementation SDServiceExample

- (AFHTTPRequestOperationManager *)requestOperationManager
{
    return [MyServiceManager sharedServiceManager].defaultRequestOperationManager;
}

- (NSString*) pathResource
{
    return @"/api";
}


- (SDHTTPMethod) requestMethodType
{
    return SDHTTPMethodGET;
}

- (Class) responseClass
{
    return [SDServiceExampleResponse class];
}

@end




@implementation SDServiceExampleRequest

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    NSMutableDictionary* dict = [[super JSONKeyPathsByPropertyKey] mutableCopy];
    
    [dict addEntriesFromDictionary:@{
                                     @"numUsers":@"results"
                                     }];
    return dict;
}



@end


@implementation SDServiceExampleResponse

@end
