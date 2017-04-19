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

#import <Foundation/Foundation.h>
#import "SDServiceGeneric.h"
#import <AFNetworking/AFNetworking.h>

typedef void (^ ServiceCompletionSuccessHandler)(id<SDServiceGenericResponseProtocol> _Nullable response);
typedef void (^ ServiceCompletionFailureHandler)(id<SDServiceGenericErrorProtocol> _Nullable error);
typedef void (^ ServiceDownloadProgressHandler)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead);
typedef void (^ ServiceUploadProgressHandler)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef NSCachedURLResponse* _Nullable (^ ServiceCachingBlock)(NSURLConnection* _Nullable connection, NSCachedURLResponse* _Nullable cachedResponse);

typedef NS_ENUM (NSInteger, SDServiceOperationType)
{
    kSDServiceOperationTypeInvalid = -1
};

@protocol SDServiceManagerDelegate;
/**
 *  Wrapper class for a single call of SDServiceGeneric.
 */
@interface SDServiceCallInfo : NSObject

- (instancetype _Nonnull) initWithService:(SDServiceGeneric* _Nonnull)service request:(id<SDServiceGenericRequestProtocol> _Nonnull)request;

@property (readonly, nonatomic, strong) SDServiceGeneric* _Nonnull service;
@property (readonly, nonatomic, strong) id<SDServiceGenericRequestProtocol> _Nonnull request;
@property (nonatomic, assign) SDServiceOperationType type;
@property (nonatomic, weak) id <SDServiceManagerDelegate> _Nullable delegate;
@property (nonatomic, assign) SEL _Nullable actionSelector;

@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, assign) int numAutomaticRetry;

@property (nonatomic, strong) ServiceCompletionSuccessHandler _Nullable completionSuccess;
@property (nonatomic, strong) ServiceCompletionFailureHandler _Nullable completionFailure;
@property (nonatomic, strong) ServiceDownloadProgressHandler _Nullable downloadProgressHandler;
@property (nonatomic, strong) ServiceUploadProgressHandler _Nullable uploadProgressHandler;
@property (nonatomic, strong) ServiceCachingBlock _Nullable cachingBlock;

@end

@protocol SDServiceManagerDelegate <NSObject>
@optional
/**
 *  Asks to delegate if can start operation for the service.
 *
 *  @param operation type of service
 *
 *  @return YES if the service could start, NO if service shouldn't start.
 */
- (BOOL) shouldStartServiceOperation:(SDServiceOperationType)operation;  // called before operation process starts (default YES, if not implemented)

/**
 *  Returns to delegate the total number of downloaded bytes.
 *
 *  @param totalBytesRead           Total bytes downloaded.
 *  @param totalBytesExpectedToRead Total bytes expected.
 */
- (void) didDownloadBytes:(long long)totalBytesRead onTotalExpected:(long long)totalBytesExpectedToRead;

/**
 *  Returns to delegate the total number of uploaded bytes.
 *
 *  @param totalBytesWritten         Total bytes uploaded.
 *  @param totalBytesExpectedToWrite Total bytes expected.
 */
- (void) didUploadBytes:(long long)totalBytesWritten onTotalExpected:(long long)totalBytesExpectedToWrite;

@required
/**
 *  Informs delegate that service did start.
 *
 *  @param operation type of service
 */
- (void) didStartServiceOperation:(SDServiceOperationType)operation;

/**
 *  Informs delegate that service did end.
 *
 *  @param operation type of service
 *  @param request   request of the service
 *  @param result    response of the service. Value nil if failure occured.
 *  @param error     response in case of failure. Value nil if operation did end with success.
 */
- (void) didEndServiceOperation:(SDServiceOperationType)operation withRequest:(id<SDServiceGenericRequestProtocol> _Nonnull)request result:(id<SDServiceGenericResponseProtocol> _Nullable)result error:(id<SDServiceGenericErrorProtocol> _Nullable)error; // called when Service operation process ends
@end

/**
 *  This calss should be extended and never used directly.
 */

#ifdef SD_LOGGER_AVAILABLE
@interface SDServiceManager : NSObject <SDLoggerModuleProtocol>
#else
@interface SDServiceManager : NSObject
#endif

+ (instancetype _Nonnull) sharedServiceManager;

/**
 *  Default Request Operation Manager.
 */
@property(nonatomic, strong) AFHTTPRequestOperationManager* _Nullable defaultRequestOperationManager;

/**
 *  Waiting time between service failure before retry call. Default is 3 seconds.
 */
@property (nonatomic, assign) NSTimeInterval timeBeforeRetry;

/**
 *  Flag to use alla services in demo mode (response retreived from local files). If you want different behaviours, use this flag on specific services.
    Default is NO.
 *
 *  @discussion enable all services in demo mode.
 */
@property (nonatomic, assign) BOOL useDemoMode;


/**
 *  Queue of all pending services.
 */
@property (nonatomic, strong, readonly) NSMutableArray<SDServiceCallInfo*>* _Nullable servicesQueue;

/**
 *  Hashtable for pending services grouped by delegate (caller). Key: hash of delegate, Value: array of SDServiceGeneric.
 */
@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber*, NSMutableArray<AFHTTPRequestOperation*>*>* _Nullable serviceInvocationDictionary;

/**
 *  This method is called every time service ends with success. Dafault implementation is empty.
 *
 *  N.B.: call super in extensions.
 *
 *  @param serviceInfo info about of service complete with success.
 */
- (void) handleSuccessForServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo withResponse:(id<SDServiceGenericResponseProtocol> _Nullable)response;

/**
 *  This method is called every time ends with failure. Default implementation is empty.
 *
 *  N.B.: call super in extensions.
 *
 *  @param serviceInfo info about of service complete with failure.
 */
- (void) handleFailureForServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo withError:(id<SDServiceGenericErrorProtocol> _Nullable)serviceError;


/**
 *  This method is called when there aren't any pending operations, alla services are removed from queue. An operation is removed from queue ONLY if:
 *     - complete with success
 *     - is cancelled
 *     - occured an error with response (error 400)
 *     - occured a connection error (no response returned) and shouldCatchFailureForMissingResponseInServiceInfo returns NO
 */
- (void) didCompleteAllServices;


/**
 *  Repeat the service call and decrement number of authomatic retries.
 *
 *  @param serviceInfo service to repeat
 */
- (void) performAutomaticRetry:(SDServiceCallInfo* _Nullable)serviceInfo;

/**
 *  Repeat all services in queue not already completed.
 */
- (void) repeatFailedServices;

/**
 *  If service expects authomatic retry, by default this method returns NO. If service doesn't provide authomatic retry, by default it returns YES.
 *
 *  YES avoid failure to be thrown to the delegate and failure block is called.
 *  NO caused that error will be suppressed.
 *
 *  Override this method if you want to handle in different modes failures without response.
 *
 *  @param serviceInfo service failed without server response.
 *  @param error error occured
 *
 *  @return flag that avoid failure without response to be thrown to the delegate and called the failure block.
 */
- (BOOL) shouldCatchFailureForMissingResponseInServiceInfo:(SDServiceCallInfo* _Nullable)serviceInfo error:(NSError* _Nullable)error;

/**
 *  Cancel all pending requests in queue for specific kind of service (with same path).
 *
 *  @param service service to cancel.
 */
- (void) cancelAllOperationsForService:(SDServiceGeneric* _Nullable)service;

/**
 *  Cancels all pending requests with the specific delegate (caller).
 *
 *  @param delegate delegate (caller) with pending services to cancel.
 */
- (void) cancelAllOperationsForDelegate:(id <SDServiceManagerDelegate> _Nullable )delegate;

/**
 *  Return number of pending operations associated to the delegate (caller).
 *
 *  @param delegate caller.
 *
 *  @return number of pendsing requests.
 */
- (NSUInteger) numberOfPendingOperationsForDelegate:(id <SDServiceManagerDelegate> _Nullable)delegate;

/**
 *  Check if there are some pending request for a given caller (delegate).
 *
 *  @return if has pending requests.
 */
- (BOOL) hasPendingOperationsForDelegate:(id <SDServiceManagerDelegate> _Nullable)delegate;

/**
 *  Return number of total pending operations.
 *
 *  @return number of pending requests.
 */
- (NSUInteger) numberOfPendingOperations;

/**
 *  Check if there are some pending operations
 *
 *  @return if has somee pending requests.
 */
- (BOOL) hasPendingOperations;

/**
 *  Enqueu service operation to call with all service info parameters.
 *
 *  @param serviceInfo object with all informations about service to call.
 */
- (void) callServiceWithServiceCallInfo:(SDServiceCallInfo* _Nonnull)serviceInfo;

/**
 *  Enqueu service operation to call with all details.
 *
 *  @param service           service to enqueue.
 *  @param request           request object.
 *  @param operationType     type of service.
 *  @param selector          selector to call after service ends with success (optional).
 *  @param numAutomaticRetry number of authomatic retry to perform after failure. 0 means that will never fire authomatic retry.
 *  @param delegate          can be used to identify the caller (optional).
 *  @param downloadBlock     block executed at every packet update (optional).
 *  @param uploadBlock       block executed at every packet upload (optional).
 *  @param completionSuccess block executed in case of service success (optional).
 *  @param completionFailure block executed in case of service failure (optional).
 *  @param cachingBlock      block executed in case of success before chaching response in NSURLCache (optional).
 */
- (void) callService:(SDServiceGeneric* _Nonnull)service
         withRequest:(id<SDServiceGenericRequestProtocol> _Nonnull)request
       operationType:(NSInteger)operationType
      responseAction:(SEL _Nullable)selector
   numAutomaticRetry:(int)numAutomaticRetry
            delegate:(id <SDServiceManagerDelegate> _Nullable)delegate
       downloadBlock:(ServiceDownloadProgressHandler _Nullable)downloadBlock
         uploadBlock:(ServiceUploadProgressHandler _Nullable)uploadBlock
   completionSuccess:(ServiceCompletionSuccessHandler _Nullable)completionSuccess
   completionFailure:(ServiceCompletionFailureHandler _Nullable)completionFailure
        cachingBlock:(ServiceCachingBlock _Nullable)cachingBlock;

/**
 * Enqueu service operation to call with all details. Service doesn't provide authomatic retry.
 *
 *  @param service           service to enqueue.
 *  @param request           request object.
 *  @param operationType     service type.
 *  @param delegate          can be used to identify the caller (optional).
 *  @param completionSuccess block executed in case of service success (optional).
 *  @param completionFailure block executed in case of service failure (optional).
 */
- (void) callService:(SDServiceGeneric* _Nonnull)service withRequest:(id<SDServiceGenericRequestProtocol> _Nonnull)request operationType:(NSInteger)operationType delegate:(id <SDServiceManagerDelegate> _Nullable)delegate completionSuccess:(ServiceCompletionSuccessHandler _Nullable)completionSuccess completionFailure:(ServiceCompletionFailureHandler _Nullable)completionFailure;

@end
