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
    return @{
            @"numUsers":@"results"
            };
}



@end


@implementation SDServiceExampleResponse

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return @{
             @"users":@"results"
            };
}

+ (NSValueTransformer*) usersJSONTransformer
{
    return [MTLJSONAdapter arrayTransformerWithModelClass:[MTLUser class]];
}

@end

@implementation MTLUser

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return @{
              @"firstName":@"name.first",
              @"lastName":@"name.last",
              @"imageUrl":@"picture.medium"
            };
}


@end
