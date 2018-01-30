//
//  MyServiceManager.m
//  Docker
//
//  Created by Francesco Ceravolo on 11/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "MyServiceManager.h"
#import "SDServiceExample.h"

@implementation MyServiceManager

- (instancetype)init
{
    self = [super init];
    if(self)
    {

        self.defaultSessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://randomuser.me"]];
        self.defaultSessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        self.defaultSessionManager.requestSerializer.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", nil];
        self.defaultSessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
        
    }
    return self;
}


- (void) callServiceForNumUsers:(NSNumber*)num withCompletion:(ServiceCompletionSuccessHandler)completion failure:(ServiceCompletionFailureHandler)failure
{
    SDServiceExample* service = [SDServiceExample new];
    SDServiceExampleRequest* request = [SDServiceExampleRequest new];
    request.numUsers = num;
    
    [self callService:service withRequest:request operationType:0 delegate:nil completionSuccess:completion completionFailure:failure];
}

@end
