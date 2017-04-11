//
//  SDServiceExample.h
//  Docker
//
//  Created by Francesco Ceravolo on 11/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

@interface SDServiceExample : SDServiceMantle

@end


@interface SDServiceExampleRequest : SDServiceMantleRequest

@property (nonatomic, strong) NSNumber* numUsers;

@end


@interface MTLUser : MTLModel <MTLJSONSerializing>

@property (nonatomic, strong) NSString* firstName;
@property (nonatomic, strong) NSString* lastName;

@property (nonatomic, strong) NSString* imageUrl;

@end


@interface SDServiceExampleResponse : SDServiceMantleResponse

@property (nonatomic, strong) NSArray<MTLUser*>* users;

@end
