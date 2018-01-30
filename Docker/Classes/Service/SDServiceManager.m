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

#import "SDServiceManager.h"
#import <Mantle/Mantle.h>
#import "SOCKit.h"
#import "NSDictionary+Docker.h"

#define MappingQueueName "com.sysdata.SDServiceManager.mappingQueue"

@implementation SDServiceCallInfo

- (instancetype) initWithService:(SDServiceGeneric*)service request:(id<SDServiceGenericRequestProtocol>)request
{
    self = [super init];
    if (self)
    {
        _service = service;
        _request = request;
    }
    return self;
}

@end



@interface SDServiceManager ()
{
    /**
     *  Thread to use for mapping operations.
     */
    dispatch_queue_t mappingQueue;
}

@property (nonatomic, strong, readwrite) NSMutableArray<SDServiceCallInfo*>* servicesQueue;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSNumber*, NSMutableArray<NSURLSessionTask*>*>* serviceInvocationDictionary;

@end

@implementation SDServiceManager

+ (instancetype) sharedServiceManager
{
    static dispatch_once_t pred;
    static id sharedServiceManagerInstance_ = nil;
    
    dispatch_once(&pred, ^{
        sharedServiceManagerInstance_ = [[self alloc] init];
    });
    
    return sharedServiceManagerInstance_;
}

- (id) init
{
    self = [super init];
    if (self)
    {
#if BLABBER
        SDLogLevel logLevel = SDLogLevelWarning;
#if DEBUG
        logLevel = SDLogLevelVerbose;
#endif
        
        [[SDLogger sharedLogger] setLogLevel:logLevel forModuleWithName:self.loggerModuleName];
#endif
        self.servicesQueue = [NSMutableArray arrayWithCapacity:0];
        self.serviceInvocationDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        self.timeBeforeRetry = 3.;
        mappingQueue = dispatch_queue_create(MappingQueueName, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark - SDLoggerModuleProtocol

#if BLABBER

- (NSString*) loggerModuleName
{
    return kServiceManagerLogModuleName;
}

- (SDLogLevel) loggerModuleLogLevel
{
    return [[SDLogger sharedLogger] logLevelForModuleWithName:self.loggerModuleName];
}

- (void) setLoggerModuleLogLevel:(SDLogLevel)level
{
    [[SDLogger sharedLogger] setLogLevel:level forModuleWithName:self.loggerModuleName];
}

#endif

#pragma mark - Call service

- (void) callService:(SDServiceGeneric*)service withRequest:(id<SDServiceGenericRequestProtocol>)request operationType:(NSInteger)operationType delegate:(id <SDServiceManagerDelegate> )delegate completionSuccess:(ServiceCompletionSuccessHandler)completionSuccess completionFailure:(ServiceCompletionFailureHandler)completionFailure
{
    [self callService:service withRequest:request operationType:operationType responseAction:nil numAutomaticRetry:0 delegate:delegate downloadBlock:nil uploadBlock:nil completionSuccess:completionSuccess completionFailure:completionFailure cachingBlock:nil];
}

- (void)  callService:(SDServiceGeneric*)service
          withRequest:(id<SDServiceGenericRequestProtocol>)request
        operationType:(NSInteger)operationType
       responseAction:(SEL)selector
    numAutomaticRetry:(int)numAutomaticRetry
             delegate:(id<SDServiceManagerDelegate>)delegate
        downloadBlock:(ServiceDownloadProgressHandler)downloadBlock
          uploadBlock:(ServiceUploadProgressHandler)uploadBlock
    completionSuccess:(ServiceCompletionSuccessHandler)completionSuccess
    completionFailure:(ServiceCompletionFailureHandler)completionFailure
         cachingBlock:(ServiceCachingBlock)cachingBlock
{
    // instantiate repeatable service to keep all details (used in case of retries)
    SDServiceCallInfo* serviceInfo = [[SDServiceCallInfo alloc] initWithService:service request:request];
    
    serviceInfo.type              = operationType;
    serviceInfo.delegate          = delegate;
    serviceInfo.actionSelector    = selector;
    serviceInfo.numAutomaticRetry = numAutomaticRetry;
    serviceInfo.downloadProgressHandler = downloadBlock;
    serviceInfo.uploadProgressHandler = uploadBlock;
    serviceInfo.completionSuccess = completionSuccess;
    serviceInfo.completionFailure = completionFailure;
    serviceInfo.cachingBlock      = cachingBlock;
    
    [self callServiceWithServiceCallInfo:serviceInfo];
}

- (void) callServiceWithServiceCallInfo:(SDServiceCallInfo*)serviceInfo
{
    // Asks to delegate if can start service.
    BOOL shouldStart = YES;
    
    if (serviceInfo.delegate && [serviceInfo.delegate respondsToSelector:@selector(shouldStartServiceOperation:)])
    {
        shouldStart = [serviceInfo.delegate shouldStartServiceOperation:serviceInfo.type];
    }
    
    if (shouldStart == NO)
    {
        SDLogModuleInfo(kServiceManagerLogModuleName, @"The delegate has blocked the operation for service %@", NSStringFromClass([serviceInfo.service class]));
        return;
    }
    
    // Advice delegate that service is started
    if (serviceInfo.delegate && [serviceInfo.delegate respondsToSelector:@selector(didStartServiceOperation:)])
    {
        [serviceInfo.delegate didStartServiceOperation:serviceInfo.type];
    }
    
    // if ServiceManager or specific service is in demo mode try to retreive response from file. Indipendently from result goes over.
    if (self.useDemoMode || ([serviceInfo.service respondsToSelector:@selector(useDemoMode)] && [serviceInfo.service useDemoMode]))
    {
        double failureChance = 0;
        
        // check if need error demo
        if([serviceInfo.service respondsToSelector:@selector(demoModeFailureChanceEvent)] && [serviceInfo.service respondsToSelector:@selector(demoModeJsonFailureFileName)] && [serviceInfo.service demoModeJsonFailureFileName].length > 0)
        {
            failureChance = [serviceInfo.service demoModeFailureChanceEvent];
        }
        
        if(failureChance > 0)
        {
            double chance = arc4random_uniform(1000)/1000.;
            if(chance < failureChance)
            {
                // simulate error in demo mode
                SDLogModuleInfo(kServiceManagerLogModuleName, @"Service %@ in DEMO MODE -> FAILURE CASE", NSStringFromClass([serviceInfo.service class]));
                
                [self callServiceInDemoModeForFailureWithServiceCallInfo:serviceInfo];
                return;
            }
        }
        
        // simulate success response in demo mode
        SDLogModuleInfo(kServiceManagerLogModuleName, @"Service %@ in DEMO MODE -> SUCCESS CASE", NSStringFromClass([serviceInfo.service class]));
        
        [self callServiceInDemoModeWithServiceCallInfo:serviceInfo];
        return;
    }
    
    // add service to queue
    [self.servicesQueue addObject:serviceInfo];
    serviceInfo.isProcessing = YES;
    
    AFHTTPSessionManager* sessionManager = [serviceInfo.service sessionManager];
    AFHTTPRequestSerializer* serializer = sessionManager.requestSerializer;
    
    // retreive path and parameters
    NSString* path = [serviceInfo.service pathResource];
    NSError* mappingError = nil;
    NSDictionary* parameters = [serviceInfo.service parametersForRequest:serviceInfo.request error:&mappingError];
    
    // remove nil parameters from request
    if ([serviceInfo.request respondsToSelector:@selector(removeNilParameters)] && [serviceInfo.request removeNilParameters])
    {
        parameters = [parameters pruneNullValues];
    }
    
    if (mappingError)
    {
        // error occured mapping request, stop operation
        [self manageMappingFailureForServiceInfo:serviceInfo HTTPStatusCode:0 andError:mappingError];
        return;
    }
    
    // mapping of request parameters
    SOCPattern* pathPattern = [SOCPattern patternWithString:path];
    path = [pathPattern stringFromObject:serviceInfo.request];
    
    // set additional request parameters
    NSDictionary<NSString*, NSString*>* additionalRequestHeaders = [serviceInfo.request additionalRequestHeaders];
    for (NSString* headerKey in additionalRequestHeaders.allKeys)
    {
        [serializer setValue:additionalRequestHeaders[headerKey] forHTTPHeaderField:headerKey];
    }
    
    // switch on HTTP method
    __weak typeof (self) weakself = self;
    NSURLSessionDataTask* task = nil;
    switch (serviceInfo.service.requestMethodType)
    {
        case SDHTTPMethodGET : {
            
            task = [sessionManager GET:path parameters:parameters progress:^(NSProgress * _Nonnull downloadProgress) {
                //-- TODO: Gestire
            } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [weakself manageResponse:responseObject inTask:task forServiceInfo:serviceInfo];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [weakself manageError:error inTask:task forServiceInfo:serviceInfo];
            }];
            
            
            break;
        }
        case SDHTTPMethodPOST : {
            if (serviceInfo.request.multipartInfos.count > 0)
            {
                
                task = [sessionManager POST:path parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                    
                    //TODO:Verificare
                    
                    for (MultipartBodyInfo* multipartInfo in serviceInfo.request.multipartInfos)
                    {
                        if (multipartInfo.data && multipartInfo.name)
                        {
                            if (multipartInfo.fileName && multipartInfo.mimeType)
                            {
                                [formData appendPartWithFileData:multipartInfo.data name:multipartInfo.name fileName:multipartInfo.fileName mimeType:multipartInfo.mimeType];
                            }
                            else
                            {
                                [formData appendPartWithFormData:multipartInfo.data name:multipartInfo.name];
                            }
                        }
                    }
                    
                } progress:^(NSProgress * _Nonnull uploadProgress) {
                    //-- TODO:Gestire
                } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    [weakself manageResponse:responseObject inTask:task forServiceInfo:serviceInfo];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    [weakself manageError:error inTask:task forServiceInfo:serviceInfo];
                }];
            }
            else
            {
                task = [sessionManager POST:path parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
                    //--
                } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    [weakself manageResponse:responseObject inTask:task forServiceInfo:serviceInfo];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    [weakself manageError:error inTask:task forServiceInfo:serviceInfo];
                }];
            }
            
            break;
        }
        case SDHTTPMethodPUT : {
            task  = [sessionManager PUT:path parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [weakself manageResponse:responseObject inTask:task forServiceInfo:serviceInfo];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [weakself manageError:error inTask:task forServiceInfo:serviceInfo];
            }];
            break;
        }
        case SDHTTPMethodDELETE : {
            task = [sessionManager DELETE:path parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [weakself manageResponse:responseObject inTask:task forServiceInfo:serviceInfo];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [weakself manageError:error inTask:task forServiceInfo:serviceInfo];
            }];
            break;
        }
        case SDHTTPMethodHEAD : {
            task = [sessionManager HEAD:path parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task) {
                [weakself manageResponse:nil inTask:task forServiceInfo:serviceInfo];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [weakself manageError:error inTask:task forServiceInfo:serviceInfo];
            }];
            break;
        }
        case SDHTTPMethodPATCH : {
            task = [sessionManager PATCH:path parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [weakself manageResponse:nil inTask:task forServiceInfo:serviceInfo];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [weakself manageError:error inTask:task forServiceInfo:serviceInfo];
            }];
            break;
        }
    }
    
    // remove additional header from serializer
    for (NSString* headerKey in additionalRequestHeaders.allKeys)
    {
        [serializer setValue:nil forHTTPHeaderField:headerKey];
    }
    
    
    // set the operation's download progress block if needed
    if (serviceInfo.downloadProgressHandler != nil || [serviceInfo.delegate respondsToSelector:@selector(didDownloadBytes:onTotalExpected:)])
    {
        // TODO Verificare
        ServiceDownloadProgressHandler downloadHandler = ^void (NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            if ([serviceInfo.delegate respondsToSelector:@selector(didDownloadBytes:onTotalExpected:)])
            {
                [serviceInfo.delegate didDownloadBytes:bytesWritten onTotalExpected:totalBytesExpectedToWrite];
            }
            
            if (serviceInfo.downloadProgressHandler)
            {
                serviceInfo.downloadProgressHandler(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
            }
        };
        [sessionManager setDownloadTaskDidWriteDataBlock:downloadHandler];
    }
    
    // set the operation's upload progress block if needed
    if (serviceInfo.uploadProgressHandler != nil || [serviceInfo.delegate respondsToSelector:@selector(didUploadBytes:onTotalExpected:)])
    {
        //TODO:VERIFICARE
        ServiceUploadProgressHandler uploadHandler = ^void (NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend){
            if ([serviceInfo.delegate respondsToSelector:@selector(didUploadBytes:onTotalExpected:)])
            {
                [serviceInfo.delegate didUploadBytes:totalBytesSent onTotalExpected:totalBytesExpectedToSend];
            }
            
            if (serviceInfo.uploadProgressHandler)
            {
                serviceInfo.uploadProgressHandler(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend);
            }
        };
        [sessionManager setTaskDidSendBodyDataBlock:uploadHandler];
    }
    // set the operation's caching block if needed
    if (serviceInfo.cachingBlock != nil)
    {
        //TODO:VERIFICARE
        [sessionManager setDataTaskWillCacheResponseBlock:serviceInfo.cachingBlock];
    }
    
    // add operation to the caller
    [self addTask:task forDelegate:serviceInfo.delegate];
}

/**
 *  Retrieve response from local file.
 */
- (void) callServiceInDemoModeWithServiceCallInfo:(SDServiceCallInfo*)serviceInfo
{
    __weak typeof (self) weakSelf = self;
    [serviceInfo.service getResultFromJSONFileWithCompletion:^(id responseObject) {
        if (responseObject)
        {
            [weakSelf manageResponse:responseObject inTask:nil forServiceInfo:serviceInfo];
        }
        else
        {
            NSString* errorString = [NSString stringWithFormat:@"Cannot find JSON file %@ for service %@", [serviceInfo.service demoModeJsonFileName], NSStringFromClass([serviceInfo.service class])];
            NSError* error = [NSError errorWithDomain:@"DEMO_MODE" code:-1 userInfo:@{ NSLocalizedDescriptionKey : errorString }];
            [weakSelf manageError:error inTask:nil forServiceInfo:serviceInfo];
        }
    }];
}

/**
 *  Retrieve error response from local file.
 */
- (void) callServiceInDemoModeForFailureWithServiceCallInfo:(SDServiceCallInfo*)serviceInfo
{
    // read json from file asking at service the demo file name
    NSString* jsonFileName;
    
    if ([serviceInfo.service respondsToSelector:@selector(demoModeJsonFailureFileName)])
    {
        jsonFileName = [serviceInfo.service demoModeJsonFailureFileName];
    }
    
    NSString* pathToFile = [[NSBundle mainBundle] pathForResource:jsonFileName ofType:@"json"];

    __weak typeof (self) weakSelf = self;
    [serviceInfo.service getResultFromJSONFileAtPath:pathToFile withCompletion:^(id  _Nullable responseObject) {
        if (responseObject)
        {
            int statusCode = 400;
            if([serviceInfo.service respondsToSelector:@selector(demoModeFailureStatusCode)])
            {
                statusCode = [serviceInfo.service demoModeFailureStatusCode];
            }
            
            NSError* mappingError = nil;
            id errorObject = [serviceInfo.service errorForObject:responseObject error:&mappingError];
            if (mappingError)
            {
                SDLogModuleError(kServiceManagerLogModuleName, @"Error object unmanaged: %@\nError: %@", responseObject, mappingError);
            }
            
            [weakSelf manageError:mappingError forServiceInfo:serviceInfo withErrorObject:errorObject statusCode:statusCode];
        }
        else
        {
            NSString* errorString = [NSString stringWithFormat:@"Cannot find JSON file %@ for service %@", jsonFileName, NSStringFromClass([serviceInfo.service class])];
            NSError* error = [NSError errorWithDomain:@"DEMO_MODE" code:-1 userInfo:@{ NSLocalizedDescriptionKey : errorString }];
            [weakSelf manageError:error inTask:nil forServiceInfo:serviceInfo];
        }
    }];
}

#pragma mark - Operation result management

- (void) manageResponse:(id)responseObject inTask:(NSURLSessionDataTask*)task forServiceInfo:(SDServiceCallInfo*)serviceInfo
{
    SDLogModuleInfo(kServiceManagerLogModuleName, @"\n**************** %@: received response\n!", [serviceInfo.service class]);
    
    NSHTTPURLResponse *httpResponse = [self httpUrlResponseWithTask:task];
    
    if (httpResponse.statusCode == 304)
    {
        NSCachedURLResponse* r = [[NSURLCache sharedURLCache] cachedResponseForRequest:task.originalRequest];
        NSError* error = nil;
        responseObject = [serviceInfo.service.sessionManager.responseSerializer responseObjectForResponse:r.response data:r.data error:&error];
    }
        
   
    
    if (!(self.useDemoMode || ([serviceInfo.service respondsToSelector:@selector(useDemoMode)] && [serviceInfo.service useDemoMode])))
    {
        [SDServiceManager printWebServiceRequest:task];
        [SDServiceManager printWebServiceResponse:task];
    }
    else
    {
        SDLogModuleVerbose(kServiceManagerLogModuleName, @"FILE CONTENT:\n%@", responseObject);
    }
    __weak typeof (self) weakself = self;
    dispatch_async(mappingQueue, ^{
        id<SDServiceGenericResponseProtocol> response = nil;
        NSError* mappingError = nil;
        response = [serviceInfo.service responseForObject:responseObject error:&mappingError];
        if (mappingError)
        {
            // errore mapping response.
            [weakself manageMappingFailureForServiceInfo:serviceInfo HTTPStatusCode:httpResponse.statusCode andError:mappingError];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (serviceInfo.actionSelector && [serviceInfo.service respondsToSelector:serviceInfo.actionSelector])
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [serviceInfo.service performSelector:serviceInfo.actionSelector withObject:response];
#pragma clang diagnostic pop
            }
            
            response.httpStatusCode = (int)httpResponse.statusCode;
            response.headers = httpResponse.allHeaderFields;
            
            [weakself handleSuccessForServiceInfo:serviceInfo withResponse:response];
            [weakself removeExecutedTask:task forDelegate:serviceInfo.delegate];
            
            if (serviceInfo.completionSuccess)
            {
                serviceInfo.completionSuccess(response);
            }
            
            if ([serviceInfo.delegate respondsToSelector:@selector(didEndServiceOperation:withRequest:result:error:)])
            {
                [serviceInfo.delegate didEndServiceOperation:serviceInfo.type withRequest:serviceInfo.request result:response error:nil];
            }
            
            if (!weakself.hasPendingTasks)
            {
                [weakself didCompleteAllServices];
            }
        });
    });
}

- (void) manageError:(NSError*)error inTask:(NSURLSessionDataTask*)task forServiceInfo:(SDServiceCallInfo*)serviceInfo
{
    if (!(self.useDemoMode || ([serviceInfo.service respondsToSelector:@selector(useDemoMode)] && [serviceInfo.service useDemoMode])))
    {
        [SDServiceManager printWebServiceRequest:task];
        [SDServiceManager printWebServiceResponse:task];
    }
    
    serviceInfo.isProcessing = NO;
    
    [self removeExecutedTask:task forDelegate:serviceInfo.delegate];
    
    SDLogModuleError(kServiceManagerLogModuleName, @"SERVICE FAILURE: %@ with code: %d", NSStringFromClass([serviceInfo.service class]), (int)error.code);
    
    if (!task.response)
    {
        // can't reach server
        // if is not cancelled and is a repeateble service, it will retry
        if (error.code != NSURLErrorCancelled)
        {
            BOOL catchFailure = [self shouldCatchFailureForMissingResponseInServiceInfo:serviceInfo error:error];
            if (catchFailure)
            {
                return;
            }
        }
        else
        {
            [self.servicesQueue removeObject:serviceInfo];
            if (!self.hasPendingTasks)
            {
                [self didCompleteAllServices];
            }
            return;
        }
    }
    
    __weak typeof (self) weakself = self;
    dispatch_async(mappingQueue, ^{
        __block id<SDServiceGenericErrorProtocol> errorObject = nil;
        if (task.response)
        {
            // if there is a service response, get the error code
            NSError* mappingError = nil;
            NSData *responseData = nil;
            if (error.userInfo)
            {
                 responseData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
            }
            id errorResponse = [serviceInfo.service.sessionManager.responseSerializer responseObjectForResponse:task.response data:responseData error:&mappingError];
            if (errorResponse)
            {
                mappingError = nil;
                errorObject = [serviceInfo.service errorForObject:errorResponse error:&mappingError];
                if (mappingError)
                {
                    SDLogModuleError(kServiceManagerLogModuleName, @"Error object unmanaged: %@\nError: %@", errorResponse, mappingError);
                }
            }
            else
            {
                SDLogModuleError(kServiceManagerLogModuleName, @"Can't retreive error from response: %@", mappingError);
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            //TODO:VERIFICARE
            NSHTTPURLResponse *httpResponse = [self httpUrlResponseWithTask:task];
            int statusCode = (int)httpResponse.statusCode;
            [weakself manageError:error forServiceInfo:serviceInfo withErrorObject:errorObject statusCode:statusCode];
        });
    });
}


- (void) manageError:(NSError*)error forServiceInfo:(SDServiceCallInfo*)serviceInfo withErrorObject:(id<SDServiceGenericErrorProtocol>)errorObject statusCode:(int)statusCode
{
    // mapping failed
    if (!errorObject)
    {
        // missing service response or mapping failure. Check what is the problem
        errorObject = [[[serviceInfo.service errorClass] alloc] init];
    }
    errorObject.httpStatusCode = statusCode;
    errorObject.error = error;
    
    // service call campleted
    // method called only if there are connection erros
    [self handleFailureForServiceInfo:serviceInfo withError:errorObject];
    
    if (serviceInfo.completionFailure)
    {
        serviceInfo.completionFailure(errorObject);
    }
    
    if ([serviceInfo.delegate respondsToSelector:@selector(didEndServiceOperation:withRequest:result:error:)])
    {
        [serviceInfo.delegate didEndServiceOperation:serviceInfo.type withRequest:serviceInfo.request result:nil error:errorObject];
    }
    
    if (!self.hasPendingTasks)
    {
        [self didCompleteAllServices];
    }
}



- (void) manageMappingFailureForServiceInfo:(SDServiceCallInfo*)serviceInfo HTTPStatusCode:(NSInteger)httpStatusCode andError:(NSError*)error
{
    __weak typeof (self) weakself = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakself handleFailureForServiceInfo:serviceInfo withError:nil];
        
        id<SDServiceGenericErrorProtocol> errorObject = [[[serviceInfo.service errorClass] alloc] init];
        errorObject.httpStatusCode = (int)httpStatusCode;
        errorObject.error = error;
        
        if (serviceInfo.completionFailure)
        {
            serviceInfo.completionFailure(errorObject);
        }
        
        if ([serviceInfo.delegate respondsToSelector:@selector(didEndServiceOperation:withRequest:result:error:)])
        {
            [serviceInfo.delegate didEndServiceOperation:serviceInfo.type withRequest:serviceInfo.request result:nil error:errorObject];
        }
        
        if (!weakself.hasPendingTasks)
        {
            [weakself didCompleteAllServices];
        }
    });
}

- (void) handleSuccessForServiceInfo:(SDServiceCallInfo*)serviceInfo withResponse:(id<SDServiceGenericResponseProtocol>)response
{
    [self.servicesQueue removeObject:serviceInfo];
}

- (void) handleFailureForServiceInfo:(SDServiceCallInfo*)serviceInfo withError:(id<SDServiceGenericErrorProtocol>)serviceError
{
    [self.servicesQueue removeObject:serviceInfo];
}

- (BOOL) shouldCatchFailureForMissingResponseInServiceInfo:(SDServiceCallInfo*)serviceInfo error:(NSError*)error
{
    // by default if service expects authomatic retry, it will avoid to throw failure to the caller (failure block never called)
    if (serviceInfo.numAutomaticRetry > 0)
    {
        [self performSelector:@selector(performAutomaticRetry:) withObject:serviceInfo afterDelay:self.timeBeforeRetry];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void) didCompleteAllServices
{
    SDLogModuleInfo(kServiceManagerLogModuleName, @"Did complete all services...");
}

#pragma mark - Automatic Retry

- (void) performAutomaticRetry:(SDServiceCallInfo*)serviceInfo
{
    if (!serviceInfo.isProcessing)
    {
        SDLogModuleInfo(kServiceManagerLogModuleName, @"Repeat service %@", serviceInfo);
        [self.servicesQueue removeObject:serviceInfo];
        serviceInfo.numAutomaticRetry--;
        [self callServiceWithServiceCallInfo:serviceInfo];
    }
}

#pragma mark - Repeatable Services management

- (void) repeatFailedServices
{
    NSArray* services = [NSArray arrayWithArray:self.servicesQueue];
    
    for (SDServiceCallInfo* serviceInfo in services)
    {
        if (!serviceInfo.isProcessing)
        {
            [self.servicesQueue removeObject:serviceInfo];
            [self callServiceWithServiceCallInfo:serviceInfo];
        }
    }
}

#pragma mark - Cancel Tasks

- (void) cancelAllTasksForService:(SDServiceGeneric*)service
{
    for (NSURLSessionDataTask* task in [service sessionManager].operationQueue.operations)
    {
        if ([[[task.originalRequest URL] relativePath] rangeOfString:service.pathResource].location != NSNotFound)
        {
            [task cancel];
        }
    }
}

- (void) cancelAllTaskForDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfServices = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    for (NSURLSessionDataTask* task  in arrayOfServices)
    {
        [task cancel];
    }
    [self.serviceInvocationDictionary removeObjectForKey:@([delegate hash])];
}

#pragma mark - Interrogation methods

- (NSUInteger) numberOfPendingTasksForDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfServices = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    return arrayOfServices.count;
}

- (BOOL) hasPendingTasksForDelegate:(id <SDServiceManagerDelegate> )delegate
{
    return ([self numberOfPendingTasksForDelegate:delegate] > 0);
}

- (NSUInteger) numberOfPendingTasks
{
    return self.servicesQueue.count;
}

- (BOOL) hasPendingTasks
{
    return ([self numberOfPendingTasks] > 0);
}

#pragma mark - Service Dictionary management

- (void) addTask:(NSURLSessionDataTask*)task forDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfTasks = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    if (!arrayOfTasks)
    {
        arrayOfTasks = [NSMutableArray arrayWithCapacity:0];
    }
    [arrayOfTasks addObject:task];
    [self.serviceInvocationDictionary setObject:arrayOfTasks forKey:@([delegate hash])];
}

- (void) removeExecutedTask:(NSURLSessionDataTask*)task  forDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfTasks = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    if (!arrayOfTasks)
    {
        return;
    }
    
    [arrayOfTasks removeObject:task];
    [self.serviceInvocationDictionary setObject:arrayOfTasks forKey:@([delegate hash])];
}

#pragma mark - Utils

+ (void) printWebServiceRequest:(NSURLSessionDataTask*)task
{
    NSURLRequest* request = [task originalRequest];
    NSString* bodyString = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
    
    SDLogModuleVerbose(kServiceManagerLogModuleName, @"REQUEST to Web Service at URL: %@;\n HEADERS:\n%@\nBODY:\n%@", [[request URL] absoluteString], request.allHTTPHeaderFields, bodyString);
}

+ (void) printWebServiceResponse:(NSURLSessionDataTask*)task
{
    NSHTTPURLResponse *httpResponse;
    
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        
        httpResponse = (NSHTTPURLResponse *)task.response;
        
        SDLogModuleVerbose(kServiceManagerLogModuleName, @"RESPONSE:\n%@\nBODY:\n%@", httpResponse, @""); //TODO: Gestire [httpResponse responseString]
    }
    else
    {
        //TODO: Gestire
    }
  
}

- (NSHTTPURLResponse *)httpUrlResponseWithTask:(NSURLSessionDataTask *)task
{
    NSHTTPURLResponse *httpResponse;
    
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        
        httpResponse = (NSHTTPURLResponse *)task.response;
        
        return httpResponse;
    }
    else
    {
        SDLogError(@"task.response isn't NSHTTPURLResponse");
    }
    return httpResponse;
}

@end
