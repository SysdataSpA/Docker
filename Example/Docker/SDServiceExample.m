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

- (AFHTTPSessionManager *)sessionManager
{
    return [MyServiceManager sharedServiceManager].defaultSessionManager;
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

- (Class)errorClass
{
    return [SDServiceExampleError class];
}


- (BOOL)useDemoMode
{
    return NO;
}

- (NSString *)demoModeJsonFileName
{
    return @"DemoFileForSuccess";
}

- (NSString *)demoModeJsonFailureFileName
{
    return @"DemoFileForFailure";
}

- (double)demoModeFailureChanceEvent
{
    return 0.5;
}

- (int)demoModeFailureStatusCode
{
    return 503;
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

@implementation SDServiceExampleError

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return @{
             @"errorMessage":@"errorMessage",
             @"technicalErrorMessage":@"techInfo.message",
             @"technicalErrorCode":@"techInfo.code"
             };
}


@end
