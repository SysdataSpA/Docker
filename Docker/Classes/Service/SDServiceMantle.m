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

#import "SDServiceMantle.h"
#import "SDDockerLogger.h"

@implementation SDServiceMantle

- (NSDictionary*) parametersForRequest:(id<SDServiceGenericRequestProtocol>)request error:(NSError**)error
{
    NSAssert([request isKindOfClass:[SDServiceMantleRequest class]], @"Request passed should subclass SDServiceMantleRequest");
    NSMutableDictionary* dict = [[MTLJSONAdapter JSONDictionaryFromModel:(SDServiceMantleRequest*)request error:error] mutableCopy];
    [dict addEntriesFromDictionary:request.additionalRequestParameters];
    if (*error)
    {
        SDLogModuleError(kServiceManagerLogModuleName, @"Request invalid error: %@", (*error).localizedDescription);
    }
    
    return dict;
}

- (id<SDServiceGenericResponseProtocol>) responseForObject:(id)object error:(NSError**)error
{
    SDServiceMantleResponse* resp = nil;
    
    if ([object isKindOfClass:[NSDictionary class]])
    {
        resp = [MTLJSONAdapter modelOfClass:[self responseClass] fromJSONDictionary:(NSDictionary*)object error:error];
    }
    else if ([object isKindOfClass:[NSArray class]])
    {
        resp = [[[self responseClass] alloc] init];
        if (resp.propertyNameForArrayResponse.length > 0 && [resp respondsToSelector:NSSelectorFromString(resp.propertyNameForArrayResponse)])
        {
            if ([resp classOfItemsInArrayResponse] != NULL)
            {
                [resp setValue:[MTLJSONAdapter modelsOfClass:[resp classOfItemsInArrayResponse] fromJSONArray:(NSArray*)object error:error] forKey:resp.propertyNameForArrayResponse];
            }
            else
            {
                SDLogModuleError(kServiceManagerLogModuleName, @"Class for method 'classOfItemsInArrayResponse' not provided for SDServiceResponse of class %@", NSStringFromClass([resp class]));
            }
        }
        else
        {
            SDLogModuleError(kServiceManagerLogModuleName, @"Unknown property for mapping response array in SDServiceResponse of class %@", NSStringFromClass([resp class]));
        }
    }
    
    if (*error)
    {
        SDLogModuleError(kServiceManagerLogModuleName, @"Response mapping error: %@", (*error).localizedDescription);
    }
    return resp;
}

- (id<SDServiceGenericErrorProtocol>) errorForObject:(id)object error:(NSError**)error
{
    SDServiceMantleError* resp = [MTLJSONAdapter modelOfClass:[self errorClass] fromJSONDictionary:object error:error];
    
    if (*error)
    {
        SDLogModuleError(kServiceManagerLogModuleName, @"Response mapping error: %@", (*error).localizedDescription);
    }
    return resp;
}

- (Class) responseClass
{
    return [SDServiceMantleResponse class];
}

- (Class) errorClass
{
    return [SDServiceMantleError class];
}

@end


@implementation SDServiceMantleRequest
@synthesize additionalRequestHeaders;
@synthesize additionalRequestParameters;
@synthesize removeNilParameters;
@synthesize multipartInfos;

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return [NSDictionary dictionary];
}

@end


@implementation SDServiceMantleResponse
@synthesize httpStatusCode;
@synthesize headers;

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return [NSDictionary dictionary];
}

- (NSString*) propertyNameForArrayResponse
{
    return nil;
}

- (Class) classOfItemsInArrayResponse
{
    return NULL;
}

@end

@implementation SDServiceMantleError
@synthesize httpStatusCode;
@synthesize error;

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return [NSDictionary dictionary];
}

@end
