#import "SDServiceManager.h"
#import <Mantle/Mantle.h>
#import "SOCKit.h"
#import "NSDictionary+Utils.h"
#import "SDDockerLogger.h"

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
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSNumber*, NSMutableArray<AFHTTPRequestOperation*>*>* serviceInvocationDictionary;

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
        self.servicesQueue = [NSMutableArray arrayWithCapacity:0];
        self.serviceInvocationDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
        self.timeBeforeRetry = 3.;
        mappingQueue = dispatch_queue_create(MappingQueueName, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark - SDLoggerModuleProtocol

#ifdef SD_LOGGER_AVAILABLE

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
        [self callServiceInDemoModeWithServiceCallInfo:serviceInfo];
        return;
    }
    
    // add service to queue
    [self.servicesQueue addObject:serviceInfo];
    serviceInfo.isProcessing = YES;
    
    AFHTTPRequestOperationManager* requestOperationManager = [serviceInfo.service requestOperationManager];
    AFHTTPRequestSerializer* serializer = requestOperationManager.requestSerializer;
    
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
    
    // switch on HTTP method
    __weak typeof(self)weakself = self;
    AFHTTPRequestOperation* operation = nil;
    switch (serviceInfo.service.requestMethodType)
    {
        case SDHTTPMethodGET : {
            operation = [requestOperationManager GET:path parameters:parameters success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
                [weakself manageResponse:responseObject inOperation:operation forServiceInfo:serviceInfo];
            } failure:^(AFHTTPRequestOperation* _Nullable operation, NSError* _Nonnull error) {
                [weakself manageError:error inOperation:operation forServiceInfo:serviceInfo];
            }];
            break;
        }
        case SDHTTPMethodPOST : {
            if (serviceInfo.request.multipartInfos.count > 0)
            {
                operation = [requestOperationManager POST:path parameters:parameters constructingBodyWithBlock:^(id < AFMultipartFormData >  _Nonnull formData) {
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
                } success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
                    [weakself manageResponse:responseObject inOperation:operation forServiceInfo:serviceInfo];
                } failure:^(AFHTTPRequestOperation* _Nullable operation, NSError* _Nonnull error) {
                    [weakself manageError:error inOperation:operation forServiceInfo:serviceInfo];
                }];
            }
            else
            {
                operation = [requestOperationManager POST:path parameters:parameters success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
                    [weakself manageResponse:responseObject inOperation:operation forServiceInfo:serviceInfo];
                } failure:^(AFHTTPRequestOperation* _Nullable operation, NSError* _Nonnull error) {
                    [weakself manageError:error inOperation:operation forServiceInfo:serviceInfo];
                }];
            }
            
            break;
        }
        case SDHTTPMethodPUT : {
            operation = [requestOperationManager PUT:path parameters:parameters success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
                [weakself manageResponse:responseObject inOperation:operation forServiceInfo:serviceInfo];
            } failure:^(AFHTTPRequestOperation* _Nullable operation, NSError* _Nonnull error) {
                [weakself manageError:error inOperation:operation forServiceInfo:serviceInfo];
            }];
            break;
        }
        case SDHTTPMethodDELETE : {
            operation = [requestOperationManager DELETE:path parameters:parameters success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
                [weakself manageResponse:responseObject inOperation:operation forServiceInfo:serviceInfo];
            } failure:^(AFHTTPRequestOperation* _Nullable operation, NSError* _Nonnull error) {
                [weakself manageError:error inOperation:operation forServiceInfo:serviceInfo];
            }];
            break;
        }
        case SDHTTPMethodHEAD : {
            operation = [requestOperationManager HEAD:path parameters:parameters success:^(AFHTTPRequestOperation* _Nonnull operation) {
                [weakself manageResponse:nil inOperation:operation forServiceInfo:serviceInfo];
            } failure:^(AFHTTPRequestOperation* _Nullable operation, NSError* _Nonnull error) {
                [weakself manageError:error inOperation:operation forServiceInfo:serviceInfo];
            }];
            break;
        }
        case SDHTTPMethodPATCH : {
            operation = [requestOperationManager PATCH:path parameters:parameters success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
                [weakself manageResponse:responseObject inOperation:operation forServiceInfo:serviceInfo];
            } failure:^(AFHTTPRequestOperation* _Nullable operation, NSError* _Nonnull error) {
                [weakself manageError:error inOperation:operation forServiceInfo:serviceInfo];
            }];
            break;
        }
    }
    
    // set additional request parameters
    for (NSString* headerKey in [serviceInfo.request additionalRequestHeaders].allKeys)
    {
        // try setting custom headers directly on request avoiding problems that headers added on serializer will appear in all next requests (also in request that don't required them)
        if([operation.request isKindOfClass:[NSMutableURLRequest class]])
        {
            NSMutableURLRequest* request = (NSMutableURLRequest*)operation.request;
            [request setValue:[serviceInfo.request additionalRequestHeaders][headerKey] forHTTPHeaderField:headerKey];
        }
        else
        {
            // fallback: added on serializer
            [serializer setValue:[serviceInfo.request additionalRequestHeaders][headerKey] forHTTPHeaderField:headerKey];
        }
    }
    
    
    // set the operation's download progress block if needed
    if (serviceInfo.downloadProgressHandler != nil || [serviceInfo.delegate respondsToSelector:@selector(didDownloadBytes:onTotalExpected:)])
    {
        ServiceDownloadProgressHandler downloadHandler = ^void (NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            if ([serviceInfo.delegate respondsToSelector:@selector(didDownloadBytes:onTotalExpected:)])
            {
                [serviceInfo.delegate didDownloadBytes:totalBytesRead onTotalExpected:totalBytesExpectedToRead];
            }
            
            if (serviceInfo.downloadProgressHandler)
            {
                serviceInfo.downloadProgressHandler(bytesRead, totalBytesRead, totalBytesExpectedToRead);
            }
        };
        
        [operation setDownloadProgressBlock:downloadHandler];
    }
    
    // set the operation's upload progress block if needed
    if (serviceInfo.uploadProgressHandler != nil || [serviceInfo.delegate respondsToSelector:@selector(didUploadBytes:onTotalExpected:)])
    {
        ServiceUploadProgressHandler uploadHandler = ^void (NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            if ([serviceInfo.delegate respondsToSelector:@selector(didUploadBytes:onTotalExpected:)])
            {
                [serviceInfo.delegate didUploadBytes:totalBytesWritten onTotalExpected:totalBytesExpectedToWrite];
            }
            
            if (serviceInfo.uploadProgressHandler)
            {
                serviceInfo.uploadProgressHandler(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
            }
        };
        
        [operation setUploadProgressBlock:uploadHandler];
    }
    
    // set the operation's caching block if needed
    if (serviceInfo.cachingBlock != nil)
    {
        [operation setCacheResponseBlock:serviceInfo.cachingBlock];
    }
    
    // add operation to the caller
    [self addOperation:operation forDelegate:serviceInfo.delegate];
}

/**
 *  Retrieve response from local file.
 */
- (void) callServiceInDemoModeWithServiceCallInfo:(SDServiceCallInfo*)serviceInfo
{
    __weak typeof(self)weakSelf = self;
    [serviceInfo.service getResultFromJSONFileWithCompletion:^(id responseObject) {
        if (responseObject)
        {
            [weakSelf manageResponse:responseObject inOperation:nil forServiceInfo:serviceInfo];
        }
        else
        {
            NSString* errorString = [NSString stringWithFormat:@"Cannot find JSON file %@ for service %@", [serviceInfo.service demoModeJsonFileName], NSStringFromClass([serviceInfo.service class])];
            NSError* error = [NSError errorWithDomain:@"DEMO_MODE" code:-1 userInfo:@{ NSLocalizedDescriptionKey : errorString }];
            [weakSelf manageError:error inOperation:nil forServiceInfo:serviceInfo];
        }
    }];
}

#pragma mark - Operation result management

- (void) manageResponse:(id)responseObject inOperation:(AFHTTPRequestOperation*)operation forServiceInfo:(SDServiceCallInfo*)serviceInfo
{
    SDLogModuleInfo(kServiceManagerLogModuleName, @"\n**************** %@: received response\n!", [serviceInfo.service class]);
    
    if (operation.response.statusCode == 304)
    {
        NSCachedURLResponse* r = [[NSURLCache sharedURLCache] cachedResponseForRequest:operation.request];
        NSError* error = nil;
        responseObject = [operation.responseSerializer responseObjectForResponse:r.response data:r.data error:&error];
    }
    
    if (!(self.useDemoMode || ([serviceInfo.service respondsToSelector:@selector(useDemoMode)] && [serviceInfo.service useDemoMode])))
    {
        [SDServiceManager printWebServiceRequest:operation];
        [SDServiceManager printWebServiceResponse:operation];
    }
    else
    {
        SDLogModuleVerbose(kServiceManagerLogModuleName, @"FILE CONTENT:\n%@", responseObject);
    }
    __weak typeof(self)weakself = self;
    dispatch_async(mappingQueue, ^{
        id<SDServiceGenericResponseProtocol> response = nil;
        NSError* mappingError = nil;
        response = [serviceInfo.service responseForObject:responseObject error:&mappingError];
        if (mappingError)
        {
            // errore mapping response.
            [weakself manageMappingFailureForServiceInfo:serviceInfo HTTPStatusCode:operation.response.statusCode andError:mappingError];
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
            
            response.httpStatusCode = (int)operation.response.statusCode;
            response.headers = operation.response.allHeaderFields;
            
            [weakself handleSuccessForServiceInfo:serviceInfo withResponse:response];
            [weakself removeExecutedOperation:operation forDelegate:serviceInfo.delegate];
            
            if (serviceInfo.completionSuccess)
            {
                serviceInfo.completionSuccess(response);
            }
            
            if ([serviceInfo.delegate respondsToSelector:@selector(didEndServiceOperation:withRequest:result:error:)])
            {
                [serviceInfo.delegate didEndServiceOperation:serviceInfo.type withRequest:serviceInfo.request result:response error:nil];
            }
            
            if (!weakself.hasPendingOperations)
            {
                [weakself didCompleteAllServices];
            }
        });
    });
}

- (void) manageError:(NSError*)error inOperation:(AFHTTPRequestOperation*)operation forServiceInfo:(SDServiceCallInfo*)serviceInfo
{
    if (!(self.useDemoMode || ([serviceInfo.service respondsToSelector:@selector(useDemoMode)] && [serviceInfo.service useDemoMode])))
    {
        [SDServiceManager printWebServiceRequest:operation];
        [SDServiceManager printWebServiceResponse:operation];
    }
    
    serviceInfo.isProcessing = NO;
    
    [self removeExecutedOperation:operation forDelegate:serviceInfo.delegate];
    
    SDLogModuleError(kServiceManagerLogModuleName, @"SERVICE FAILURE: %@ with code: %d", NSStringFromClass([serviceInfo.service class]), (int)error.code);
    
    if (!operation.response)
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
            if (!self.hasPendingOperations)
            {
                [self didCompleteAllServices];
            }
            return;
        }
    }
    
    __weak typeof(self)weakself = self;
    dispatch_async(mappingQueue, ^{
        __block id<SDServiceGenericErrorProtocol> errorObject = nil;
        if (operation.response)
        {
            // if there is a service response, get the error code
            NSError* mappingError = nil;
            id errorResponse = [serviceInfo.service.requestOperationManager.responseSerializer responseObjectForResponse:operation.response data:operation.responseData error:&mappingError];
            if (errorResponse)
            {
                mappingError = nil;
                errorObject = [serviceInfo.service errorForObject:errorResponse error:&mappingError];
                errorObject.httpStatusCode = (int)operation.response.statusCode;
                errorObject.error = error;
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
            // mapping failed
            if (!errorObject)
            {
                // missing service response or mapping failure. Check what is the problem
                errorObject = [[[serviceInfo.service errorClass] alloc] init];
                errorObject.httpStatusCode = (int)operation.response.statusCode;
                errorObject.error = error;
            }
            // service call campleted
            // method called only if there are connection erros
            [weakself handleFailureForServiceInfo:serviceInfo withError:errorObject];
            
            if (serviceInfo.completionFailure)
            {
                serviceInfo.completionFailure(errorObject);
            }
            
            if ([serviceInfo.delegate respondsToSelector:@selector(didEndServiceOperation:withRequest:result:error:)])
            {
                [serviceInfo.delegate didEndServiceOperation:serviceInfo.type withRequest:serviceInfo.request result:nil error:errorObject];
            }
            
            if (!weakself.hasPendingOperations)
            {
                [weakself didCompleteAllServices];
            }
        });
    });
}

- (void) manageMappingFailureForServiceInfo:(SDServiceCallInfo*)serviceInfo HTTPStatusCode:(NSInteger)httpStatusCode andError:(NSError*)error
{
    __weak typeof(self)weakself = self;
    
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
        
        if (!weakself.hasPendingOperations)
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


- (BOOL) shouldCatchFailureForMissingResponseInServiceInfo:(SDServiceCallInfo*)serviceInfo error:(NSError *)error
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

#pragma mark - Cancel Operations

- (void) cancelAllOperationsForService:(SDServiceGeneric*)service
{
    for (AFHTTPRequestOperation* operation in [service requestOperationManager].operationQueue.operations)
    {
        if ([[[operation.request URL] relativePath] rangeOfString:service.pathResource].location != NSNotFound)
        {
            [operation cancel];
        }
    }
}

- (void) cancelAllOperationsForDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfServices = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    for (AFHTTPRequestOperation* operation in arrayOfServices)
    {
        [operation cancel];
    }
    [self.serviceInvocationDictionary removeObjectForKey:@([delegate hash])];
}

#pragma mark - Interrogation methods

- (NSUInteger) numberOfPendingOperationsForDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfServices = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    return arrayOfServices.count;
}

- (BOOL) hasPendingOperationsForDelegate:(id <SDServiceManagerDelegate> )delegate
{
    return ([self numberOfPendingOperationsForDelegate:delegate] > 0);
}

- (NSUInteger) numberOfPendingOperations
{
    return self.servicesQueue.count;
}

- (BOOL) hasPendingOperations
{
    return ([self numberOfPendingOperations] > 0);
}

#pragma mark - Service Dictionary management

- (void) addOperation:(AFHTTPRequestOperation*)operation forDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfOperations = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    if (!arrayOfOperations)
    {
        arrayOfOperations = [NSMutableArray arrayWithCapacity:0];
    }
    [arrayOfOperations addObject:operation];
    [self.serviceInvocationDictionary setObject:arrayOfOperations forKey:@([delegate hash])];
}

- (void) removeExecutedOperation:(AFHTTPRequestOperation*)operation forDelegate:(id <SDServiceManagerDelegate> )delegate
{
    NSMutableArray* arrayOfOperations = [self.serviceInvocationDictionary objectForKey:@([delegate hash])];
    
    if (!arrayOfOperations)
    {
        return;
    }
    
    [arrayOfOperations removeObject:operation];
    [self.serviceInvocationDictionary setObject:arrayOfOperations forKey:@([delegate hash])];
}

#pragma mark - Utils

+ (void) printWebServiceRequest:(AFHTTPRequestOperation*)operation
{
    NSURLRequest* request = [operation request];
    NSString* bodyString = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
    
    SDLogModuleVerbose(kServiceManagerLogModuleName, @"REQUEST to Web Service at URL: %@;\n HEADERS:\n%@\nBODY:\n%@", [[request URL] absoluteString], request.allHTTPHeaderFields, bodyString);
}

+ (void) printWebServiceResponse:(AFHTTPRequestOperation*)operation
{
    SDLogModuleVerbose(kServiceManagerLogModuleName, @"RESPONSE:\n%@\nBODY:\n%@", [operation response], [operation responseString]);
}

@end