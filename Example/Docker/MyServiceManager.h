//
//  MyServiceManager.h
//  Docker
//
//  Created by Francesco Ceravolo on 11/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

@interface MyServiceManager : SDServiceManager


- (void) callServiceForNumUsers:(NSNumber*)num withCompletion:(ServiceCompletionSuccessHandler)completion failure:(ServiceCompletionFailureHandler)failure;

@end
