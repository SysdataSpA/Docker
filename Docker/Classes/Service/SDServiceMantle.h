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

#import "SDServiceGeneric.h"
#import <Mantle/Mantle.h>

/**
 * This calss should be used as superclass for service that uses content type 'application/json'. Use Mantle to map request and response
 *
 *  Specific service should subclass SDServiceMantle to implement details.
 */
@interface SDServiceMantle : SDServiceGeneric

@end

/**
 *  This class represent base request superclass when use Mantle to map request (application/json).
 *
 *  Request of specific servic should subclass SDServiceMantleRequest and define parameters and mapping that will be set in body or query string (depending of HTTP method set)
 *
 *  To define request mapping implements MTLJSONSerializing method +(NSDictionary*)JSONKeyPathsByPropertyKey.
 */
@interface SDServiceMantleRequest : MTLModel<MTLJSONSerializing, SDServiceGenericRequestProtocol>

@end

/**
 *  This class represent base response superclass when use Mantle to map response (application/json).
 *
 *  Response of specific servic should subclass SDServiceMantleResponse and define parameters and mapping that will be returned from service
 *
 *  To define response mapping implements MTLJSONSerializing method +(NSDictionary*)JSONKeyPathsByPropertyKey.
 */
@interface SDServiceMantleResponse : MTLModel<MTLJSONSerializing, SDServiceGenericResponseProtocol>

@end

/**
 *  This class represent base error superclass when use Mantle to map error (application/json).
 *
 *  Error of specific servic should subclass SDServiceMantleError and define parameters and mapping that will be returned from service when fails
 *
 *  To define error mapping implements MTLJSONSerializing method +(NSDictionary*)JSONKeyPathsByPropertyKey.
 */
@interface SDServiceMantleError : MTLModel<MTLJSONSerializing, SDServiceGenericErrorProtocol>

@end
