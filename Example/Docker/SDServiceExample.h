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


@interface SDServiceExampleResponse : SDServiceMantleResponse

@end
