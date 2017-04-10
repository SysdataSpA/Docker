//
//  SDDownloadManagerWithCache.h
//  YooxNative
//
//  Created by Francesco Ceravolo on 27/06/14.
//  Copyright (c) 2014 Yoox Group. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>


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


typedef void (^ SDDownloadManagerCheckSizeCompletion)(double totalSize, NSUInteger numElementsToDownload);
typedef void (^ SDDownloadManagerBatchOperationProgressHandler)(double totalSize, NSUInteger numElementsToDownload);
typedef void (^ SDDownloadManagerBatchOperationCompletion)();



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

#ifdef SD_LOGGER_AVAILABLE
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
 *  @param urlString          url of resource (use this for "normal" request)
 *  @param request            use request if you want to set specific parameters or custom headers to reach your resources (use this if resource is behind a custom service)
 *  @param type               type of resource to retreive a casted object
 *  @param options            options object to override global settings for the specific request
 *  @param completionSuccess  block called when resorce is retreived
 *  @param progress           block called to check download progress
 *  @param completionFailure  block called when a failure occured
 */

- (void) getResourceAtUrl:( NSString* _Nonnull )urlString completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable )completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable )progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;

- (void) getResourceAtUrl:(NSString* _Nonnull)urlString type:(DownloadOperationType)type options:(SDDownloadOptions* _Nullable)options completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;


- (void) getResourceWithRequest:(NSMutableURLRequest* _Nonnull)request completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;

- (void) getResourceWithRequest:(NSMutableURLRequest* _Nonnull)request type:(DownloadOperationType)type options:(SDDownloadOptions* _Nullable)options completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;

/**
 *  Return the local path where persist the resource at the given url. It will be used to retreive manually the resource or to check if is present locally (ex. [UIImage imageWithContentOFUrl: <this path>])
 
    Default: local path set in <fileSystemPath>/<MD5 of url>
 *
 *  @param urlString    url of the resource
 *
 *  @return path        local path where persist the resource
 */
- (NSString* _Nonnull) localResourcePathForUrlString:(NSString* _Nonnull)urlString;


#pragma mark - Count size

/**
 *  Total size (in byte) of the resource checked with countDownloadSizeForResourceAtUrls:completion: (if some local resources are valid will not be count)
 */
@property (atomic, readonly) long long downloadElementsTotalSize;

/**
 *  Number of files to download checked with countDownloadSizeForResourceAtUrls:completion: (if some local resources are valid will not be count)
 */
@property (nonatomic, readonly) NSUInteger downloadOperationQueueCount;

/**
 *  YES if the download batch is processing (after call downloadAllElementsCheckedWithProgress:completion)
 */
@property (nonatomic, readonly) BOOL downloadElementsProcessing;

/**
 *  YES if the count size batch is processing (after call countDownloadSizeForResourceAtUrls:completion:)
 */
@property (nonatomic, readonly) BOOL checkSizeElementsProcessing;

/**
 *  Controlla se la risorsa è da scaricare (secondo le logiche sopra) e in tal caso fa una chiamata HEAD per sapere il Content-Lenght in modo da contare la dimensione del file.
 *  Ogni risorsa da scaricare va ad incrementare downloadElementsTotalSize e viene accodata in una coda, in modo da poter cominciarne il caricamento con downloadAllElementsChecked.
 *  Una volta terminate tutte le richieste HEAD viene inviata una notifica di coda vuota NOTIFICATION_DOWNLOAD_QUEUE_EMPTY.
 *
 *  @param type               tipo della risorsa
 *  @param urlString          url da cui scaricare
 *  @param options            opzioni nel caso la risorsa si debba scaricare (possono essere concatenate)
 *  @param expirationInterval data limite entro cui la risorsa locale si ritiene valida
 */

- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>* _Nonnull)urlStrings completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>* _Nonnull)urlStrings options:(SDDownloadOptions* _Nullable)options completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>* _Nonnull)urlStrings options:(SDDownloadOptions* _Nullable)options progress:(SDDownloadManagerBatchOperationProgressHandler _Nullable)progress completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;

- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>* _Nonnull)requests completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>* _Nonnull)requests options:(SDDownloadOptions* _Nullable)options completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;
- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>* _Nonnull)requests options:(SDDownloadOptions* _Nullable)options progress:(SDDownloadManagerBatchOperationProgressHandler _Nullable)progress completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion;


/**
 *  Start downloading all resources checked with countDownloadSizeForResourceAtUrls:completion: that need to be downloaded.
 *  It will fired a progress handler to return the amount of remaining size and number of files.
 *
 *  @param progress           handler of progress
 *  @param urlString          url da cui scaricare
 *  @param options            opzioni nel caso la risorsa si debba scaricare (possono essere concatenate)
 *  @param expirationInterval data limite entro cui la risorsa locale si ritiene valida
 */
- (void) downloadAllElementsCheckedWithProgress:(SDDownloadManagerBatchOperationProgressHandler _Nullable)progress completion:(SDDownloadManagerBatchOperationCompletion _Nullable)completion;



#pragma mark - Cancel/Reset

/**
 *  Cancel all pending request in reuestOperationManager
 *
 */
- (void) cancelAllDownloadRequests;


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
- (NSURL* _Nonnull) encodedUrlFromString:(NSString* _Nonnull)urlString;

@end
