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

@import AFNetworking;
#import "SDDockerLogger.h"

/**
 *  Type of resource you want retreive. If not specified it will be return a generic NSData object.
 If specified DownloadOperationTypeImage it will returned an UIImage instance
 */
typedef NS_ENUM (NSUInteger, DownloadOperationType)
{
    DownloadOperationTypeGeneric,                               // generic type (NSData instance)
    DownloadOperationTypeImage                                  // UIImage type
};

/**
 *  Result type occured obtaining the resource. It's returned inside che competion block SDDownloadManagerCompletionSuccessHandler
 */
typedef NS_ENUM (NSUInteger, DownloadOperationResultType)
{
    // invalid result
    DownloadOperationResultInvalid,
    
    // local resource exists and still valid (expirationInterval not expired yet): doesn't required HEAD request to check if local resource is still valid
    DownloadOperationResultLoadLocallyStillValid,
    
    // resource exixsts locally but should be checked validity by HEAD request. The completion block will returned this result type in this phase only if SDDownloadOptions has notifyBeforeValidityCheck = true
    // WARNING: in this moment the returned resource could be different from the finally one
    DownloadOperationResultLoadLocallyCheckingValid,
    
    // HEAD request verified that local resource is still valid
    DownloadOperationResultLoadLocallyCheckingValidSuccessed,
    
    // HEAD request can't verify resource
    DownloadOperationResultLoadLocallyCheckingValidFailed,
    
    // local resource is download or updated
    DownloadOperationResultDownloadedNew,
    
    // local resource failed to download or update
    DownloadOperationResultDownloadedNewFailed,
    
    // resource is retreived form bundle
    DownloadOperationResultBundleRetreived
};


typedef void (^ SDDownloadManagerCompletionSuccessHandler)(id _Nullable downloadedObject, NSString* _Nullable urlString, NSString* _Nullable localPath, DownloadOperationResultType resultType);
typedef void (^ SDDownloadManagerProgressHandler)(NSString* _Nullable urlString, NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead);
typedef void (^ SDDownloadManagerCompletionFailureHandler)(NSString* _Nullable urlString, NSError* _Nullable error);


typedef void (^ SDDownloadManagerCheckSizeCompletion)(long long totalSize, long numElementsToDownload);

typedef void (^ SDDownloadManagerBatchOperationProgressHandler)(long long totalSizeExpected, long long sizeRemaining, long numElementsToDownloadExpected, long numElementsToDownloadRemaining);
typedef void (^ SDDownloadManagerBatchOperationCompletion)(BOOL downloadCompleted);



//---------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------

/**
 *  Use this options to overrides gloabl settings of Manager for single requests.
 */
@interface SDDownloadOptions : NSObject

// the local path in file system where the resource should be saved
@property (nonatomic, strong) NSString* _Nonnull localPath;

// expiration time interval
@property (nonatomic, assign) NSTimeInterval expirationInterval;

// disable check local resource, download will start immediatly
@property (nonatomic, assign) BOOL forceDownload;

// use bundle to retreive the resource if present
@property (nonatomic, assign) BOOL useBundle;

// disable save after download
@property (nonatomic, assign) BOOL saveDisabled;

// notify the temporary local resource before checking validity with HEAD request.
// WARNING: in this moment the returned resource could be different from the finally one
@property (nonatomic, assign) BOOL notifyBeforeValidityCheck;

@end



//---------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------

#if BLABBER
@interface SDDownloadManager : NSObject <SDLoggerModuleProtocol>
#else
@interface SDDownloadManager : NSObject
#endif

+ (instancetype _Nonnull) sharedManager;


/**
 *  Enable use of internal ExpirationDatePlist.plist that preserve expiration date for each resource <url : expirationDate>. This date depends by the expirationInterval set for the resource and represent the available time while any HEAD request are fired to check resources validity.
 *  If enable, if the DOwnloadManager retreive the resource locally, checks if his expiration date is passed. If still valid, the resource is returned without other check (HEAD request), otherwise it will fire a HEAD request to compare his modified date.
 This plist file is persisted every time the app goes to background.
 
 Default: YES
 */
@property(nonatomic, assign) BOOL useExpirationDatePlist;

/**
 *  Default expiration interval for the resource. It will be overrideen for specific resources using SDDownloadOptions
 *
 *  Default: 7200 seconds (2 hours)
 */
@property(nonatomic, assign) NSTimeInterval defaultExpirationInterval;

/**
 *  Enable internal NSCache to keep downloaded/retreived resources and avoid file system accesses to have faster performances.
 *
 *  WARNING: memory usage could grow much
 *  Default: NO
 */
@property(nonatomic, assign) BOOL useMemoryCache;


/**
 *  Set up to save resource after download into file system folder (<fileSystemPath>)
 *
 *  Default: YES
 */
@property(nonatomic, assign) BOOL useFileSystem;

/**
 *  Check resource in bundle before all. The bundle folder is set in <bundlePath> property.
 *
 *  Default: YES only if bundlePath != nil
 */
@property(nonatomic, assign) BOOL useBundle;

/**
 *  Check local resource validity whit HEAD request comparing MODIFIED DATE. If set to FALSE, if the resource is available locally it will consider valid and returned to callers.
 *  Disable only if your resources Server will provide a new url every time it will update the resource, otherwise if updates will be at same urls, you can't rereive updates once you have a local version of the resource.
 *
 *  WARNING: set to YES if your Server will update resource at same urls
 *  Default: YES
 */
@property(nonatomic, assign) BOOL useHeadRequestToCheckUpdates;

/**
 *  file system path where keep download resources
 *
 *  Default: /Cache/downloads
 */
@property(nonatomic, strong) NSString* _Nonnull fileSystemPath;

/**
 *  Bundle folder where insert seed resources. Resources in this bundle folder will be checked before checking updates.
 *  If you want adavnced configuration look at SDDownloadManagerUtils to import/export resources and simulate a seed pool of resources.
 *
 *  Default: seed_resources
 */
@property(nonatomic, strong) NSString* _Nonnull bundlePath;

/**
 *  timeout interval for each request
 *
 *  Default: 120 seconds
 */
@property(nonatomic, assign) NSUInteger timeoutInterval;

/**
 *  Date formatter of your Server to compare the Modified-Date and look for update.
 *
 *  Default: format = EEE, dd MMM yyyy HH:mm:ss 'GMT'       locale = en-US
 */
@property (nonatomic, strong, readonly) NSDateFormatter* _Nonnull serverDateFormatter;

/**
 *  default RequestOperationManager
 */
@property(nonatomic, strong, readonly) AFHTTPRequestOperationManager* _Nonnull downloadRequestOperationManager;




#pragma mark - Download

/**
 *  Looks for a resource locally and if not available or not still valid it will download it.
 *  Before all it looks in Memory Cache or File System (depending your settings) using MD5 of his url as key. If there is a resource locally, it checks the validity using the ExpirationDatePlist (depending useExpirationDatePlist settings) and checks its expiration date.
 If resource is still valid is returned immediately, otherwise it fires a HEAD request (depending of useHeadRequestToCheckUpdates setting) to compare the Modified-Date.
 If Modified-Date is the same, local resource is valid and returned, otherwise it starts to download the update.
 Once the resource is download it will update the expiration date inside the ExpirationDatePlist (if used), saved inside NSCache (if set) and into File System (if set)
 *
 *
 *  @param urlString  / request        url of resource (use this for "normal" request)
 or
 use request if you want to set specific parameters or custom headers to reach your resources (use this if resource is behind a custom service)
 *  @param type               type of resource to retreive a casted object
 *  @param options            options object to override global settings for the specific request
 *  @param completionSuccess  block called when resorce is retreived
 *  @param progress           block called to check download progress
 *  @param completionFailure  block called when a failure occured
 */
- (void) getResourceAtUrl:(NSString* _Nonnull)urlString type:(DownloadOperationType)type options:(SDDownloadOptions* _Nullable)options completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;

- (void) getResourceAtUrl:( NSString* _Nonnull )urlString completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable )completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable )progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;

- (void) getResourceWithRequest:(NSMutableURLRequest* _Nonnull)request type:(DownloadOperationType)type options:(SDDownloadOptions* _Nullable)options completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;

- (void) getResourceWithRequest:(NSMutableURLRequest* _Nonnull)request completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;


/**
 *  Every time you want to download a resource for a specific url, the SDDownloadManager add his blocks in a structure, as a publish-subscriber pattern.
 *  When the SDDownloadManager ends, it notifies and perform all blocks registered as subscriber for it. If you want to avoid this, you can use following methods to remove subscribers for a specific url, giving the block used in getResourceAtUrl:
 
 *  Method to avoid the completion calls in all owners that asked to retrieve a resource for a specific url.
 *  Base implementation starts the SDDownloadManager to retrieve the resource.
 *  In extensions you should call super.
 *
 *  @param urlString                url of the desired resource
 *  @param completionSuccess        the complition block that should be invoked when the download finishes and that you want to remove
 
 */
- (void) removeSubscriberForUrl:(NSString* _Nonnull)urlString withCompletionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nonnull)completionSuccess;
- (void) removeAllSubscribersForUrl:(NSString* _Nonnull)urlString;

/**
 *  Return the local path where persist the resource at the given url. It will be used to retreive manually the resource or to check if is present locally (ex. [UIImage imageWithContentOFUrl: <this path>])
 
 Default: local path set in <fileSystemPath>/<MD5 of url>
 *
 *  @param urlString    url of the resource
 *
 *  @return path        local path where persist the resource
 */
- (NSString* _Nullable) localResourcePathForUrlString:(NSString* _Nonnull)urlString;

/**
 *  Check if the resource that corresponds to a given url is already stored locally.
 *
 *  @param urlString    url of the resource
 *
 *  @return if is stored locally
 */
- (BOOL) isStoredLocallyResourceForUrlString:(NSString* _Nonnull)urlString;


#pragma mark - Count size

/**
 *  Total size (in byte) of the resource checked with countDownloadSizeForResourceAtUrls:completion: (if some local resources are valid will not be count)
 */
@property (atomic, readonly) long long downloadElementsExpectedTotalSize;

/**
 *  Size (in byte) of the remaining resource in download
 */
@property (atomic, readonly) long long downloadElementsRemainingSize;


/**
 *  Number of files to download checked with countDownloadSizeForResourceAtUrls:completion: (if some local resources are valid will not be count)
 */
@property (nonatomic, readonly) long downloadOperationExpectedQueueCount;

/**
 *  Number of files of remaining resources in download
 */
@property (nonatomic, readonly) long downloadOperationRemainingQueueCount;

/**
 *  YES if the download batch is processing (after call downloadAllElementsCheckedWithProgress:completion)
 */
@property (nonatomic, readonly) BOOL downloadElementsProcessing;

/**
 *  YES if the count size batch is processing (after call countDownloadSizeForResourceAtUrls:completion:)
 */
@property (nonatomic, readonly) BOOL checkSizeElementsProcessing;

/**
 *  Check if each resources should be download using options and global settings (defined before). In this case makes a HEAD request to check the file size using Content-Lenght header's field.
 *  Each resource that should be downloaded increments downloadElementsExpectedTotalSize and is enqueued for the next download that could be start with downloadAllElementsCheckedWithProgress:completion method.
 *
 *  @param urlStrings         urls of resources to download
 *  @param options            options to use
 */
- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>* _Nonnull)urlStrings options:(NSArray<SDDownloadOptions*>* _Nullable)options progress:(SDDownloadManagerCheckSizeCompletion _Nullable)progress completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>* _Nonnull)urlStrings completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>* _Nonnull)urlStrings options:(NSArray<SDDownloadOptions*>* _Nullable)options completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;

- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>* _Nonnull)requests completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>* _Nonnull)requests options:(NSArray<SDDownloadOptions*>* _Nullable)options completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>* _Nonnull)requests options:(NSArray<SDDownloadOptions*>* _Nullable)options progress:(SDDownloadManagerCheckSizeCompletion _Nullable)progress completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;


/**
 *  Start downloading all resources checked with countDownloadSizeForResourceAtUrls:completion: that need to be downloaded.
 *  It will fired a progress handler to return the amount of remaining size and number of files.
 *
 *  @param progress           handler of progress
 *  @param completion         handler of completion
 */
- (void) downloadAllElementsCheckedWithProgress:(SDDownloadManagerBatchOperationProgressHandler _Nullable)progress completion:(SDDownloadManagerBatchOperationCompletion _Nullable)completion;



#pragma mark - Cancel/Reset

/**
 *  Cancel all pending request in reuestOperationManager
 *
 */
- (void) cancelAllDownloadRequests;
- (void) cancelAllDownloadRequestsRemovingSubscribers:(BOOL)removeSubscribers;
- (void) cancelDownloadRequestForUrlString:(NSString* _Nonnull)urlString;
- (void) cancelDownloadRequestForUrlString:(NSString* _Nonnull)urlString removingSubscribers:(BOOL)removeSubscribers;

/**
 *  reset internal MemoryCache and ExpirationDatePlist
 */
- (void) resetMemoryCache;

/**
 *  Purge all files from file system which are older than the given dates. Compares the actual date with the downloaded date
 *
 *  @param numdays num days for consider a local file old and eligible to purge
 */
- (void) purgeLocalFilesOlderThanNumDays:(NSUInteger)numdays;


#pragma mark Utils

/**
 *  Encode by adding percent escaping at url string
 *
 *  @param urlString url to encode
 *
 *  @return url encoded
 */
- (NSURL* _Nullable) encodedUrlFromString:(NSString* _Nonnull)urlString;

@end


