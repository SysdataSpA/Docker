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

#import "SDDownloadManager.h"
#import "DKRFileManager.h"
#import "NSString+Hashing.h"

#define OPERATION_INFO_LOCAL_PATH              @"localPath"
#define OPERATION_INFO_OPTIONS                 @"options"

#define LOCAL_STORED_OBJECT_LAST_MODIFIED_DATE @"lastModfiedDate"
#define LOCAL_STORED_OBJECT                    @"object"
#define LOCAL_STORED_PATH                      @"localStoredPath"

#define CONTENT_LENGTH_EMPTY_IMAGE             100

#define OPERATION_QUEUE_COUNT                  10

#define DEFAULT_TIMEOUT_INTERVAL               120  // 2 min
#define DEFAULT_EXPIRATION_INTERVAL            7200 // 2h

#define DEAFULT_PATH_FOLDER                    @"download"

#define DEFAULT_BUNDLE_FOLDER                  @"seed_resources"

#define DEFAULT_PURGE_FILES_NUM_DAYS           365


#define DOWNLOAD_OPERATION_INFO_RESULT_TYPE    @"resultType"



// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------


@interface SDDownloadObjectInfo : NSObject

@property (nonatomic, strong) SDDownloadManagerCompletionSuccessHandler successHandler;
@property (nonatomic, strong) SDDownloadManagerProgressHandler progressHandler;
@property (nonatomic, strong) SDDownloadManagerCompletionFailureHandler failureHandler;

@end

@implementation SDDownloadObjectInfo
@end



// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------

@interface SDDownloadOptions ()


@end

@implementation SDDownloadOptions

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        self.expirationInterval = [SDDownloadManager sharedManager].defaultExpirationInterval;
        self.useBundle = [SDDownloadManager sharedManager].useBundle;
    }
    return self;
}

@end



// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------

@interface SDDownloadStatistic : NSObject 

@property (nonatomic, assign, readwrite) long long totalSizeExpected;
@property (nonatomic, assign, readwrite) long long sizeRemaining;

@end

@implementation SDDownloadStatistic

@end

// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------





@interface SDDownloadManager () <NSCacheDelegate>
{
    dispatch_queue_t expirationDateInfoQueue;
    
    NSTimer* timerEmptyQueueNotification;
}


@property (atomic, strong) NSMutableDictionary* expirationDateInfo;
@property (nonatomic, strong) NSString* expirationDateInfoPath;

@property (nonatomic, strong) NSCache* memoryCache;

@property (nonatomic, strong, readwrite) NSDateFormatter* serverDateFormatter;
@property (nonatomic, strong, readwrite) AFHTTPRequestOperationManager* downloadRequestOperationManager;

@property (nonatomic, readwrite) BOOL checkSizeElementsProcessing;
@property (nonatomic, strong) SDDownloadManagerCheckSizeCompletion checkSizeCompletion;
@property (nonatomic, strong) SDDownloadManagerCheckSizeCompletion checkSizeProgressHandler;


@property (nonatomic, readwrite) BOOL downloadElementsProcessing;
@property (nonatomic, strong) NSMutableDictionary<NSString*, SDDownloadStatistic*>* downloadElementsSizeInfos;
@property (nonatomic, strong) NSMutableArray<AFHTTPRequestOperation*>* downloadElementsOperations;

@property (atomic, readwrite) long long downloadElementsExpectedTotalSize;
@property (atomic, readwrite) long long downloadElementsRemainingSize;

@property (nonatomic, readwrite) long downloadOperationExpectedQueueCount;

@property (nonatomic, strong) SDDownloadManagerBatchOperationProgressHandler downloadElementsProgressHandler;
@property (nonatomic, strong) SDDownloadManagerBatchOperationCompletion downloadElementsCompletionHandler;


@property (nonatomic, strong) NSMutableDictionary<NSString*, NSMutableArray<SDDownloadObjectInfo*>*>* urlDownloadersDictionary;

@end


@implementation SDDownloadManager

+ (instancetype) sharedManager
{
    static dispatch_once_t pred;
    static id sharedManagerInstance = nil;
    
    dispatch_once(&pred, ^{
        sharedManagerInstance = [[self alloc] init];
    });
    
    return sharedManagerInstance;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        // Log module
#if BALBBER
        SDLogLevel logLevel = SDLogLevelWarning;
#if DEBUG
        logLevel = SDLogLevelInfo;
#endif
        [[SDLogger sharedLogger] setLogLevel:logLevel forModuleWithName:self.loggerModuleName];
#endif
        // fake url
        self.downloadRequestOperationManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://www.sysdata.it"]];
        self.downloadRequestOperationManager.operationQueue.maxConcurrentOperationCount = OPERATION_QUEUE_COUNT;                                                                                                                               // NSOperationQueueDefaultMaxConcurrentOperationCount; NB non usarlo perché non gestito bene e va in timeout
        self.downloadRequestOperationManager.securityPolicy.allowInvalidCertificates = NO;
        self.downloadRequestOperationManager.responseSerializer.acceptableContentTypes = nil;
        
        self.downloadElementsOperations = [NSMutableArray new];
        self.downloadElementsSizeInfos = [NSMutableDictionary new];
        
        self.urlDownloadersDictionary = [NSMutableDictionary new];
        
        
        self.serverDateFormatter = [[NSDateFormatter alloc] init];
        [self.serverDateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss 'GMT'"];
        [self.serverDateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
        
        
        // default Settings
        self.useExpirationDatePlist = YES;
        self.useMemoryCache = NO;
        self.useFileSystem = YES;
        self.useHeadRequestToCheckUpdates = YES;
        
        NSString* localPath = [[[DKRFileManager sharedManager] cacheDirectory] stringByAppendingPathComponent:DEAFULT_PATH_FOLDER];
        if ([DKRFileManager createDirectoryAtPath:localPath withIntermediateDirectories:YES])
        {
            self.fileSystemPath = localPath;
        }
        self.bundlePath = [[NSBundle mainBundle] pathForResource:DEFAULT_BUNDLE_FOLDER ofType:@""];
        self.useBundle = YES;
        
        self.timeoutInterval = DEFAULT_TIMEOUT_INTERVAL;
        self.defaultExpirationInterval = DEFAULT_EXPIRATION_INTERVAL;
        
        self.memoryCache = [[NSCache alloc] init];
        self.memoryCache.delegate = self;
        
        
        expirationDateInfoQueue = dispatch_queue_create("it.sysdata.downloadcache.info", DISPATCH_QUEUE_SERIAL);
        [self synchronizeCacheInfos];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(writeExpirationDateInfoIntoPlist) name:UIApplicationWillResignActiveNotification object:nil];
    }
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL) useBundle
{
    if (!_useBundle)
    {
        return NO;
    }
    return (self.bundlePath != nil);
}

- (BOOL) useExpirationDatePlist
{
    return _useExpirationDatePlist && self.useHeadRequestToCheckUpdates;
}

#pragma mark - SDLoggerModuleProtocol

#if BLABBER

- (NSString*) loggerModuleName
{
    return kDownloadManagerLogModuleName;
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

#pragma mark Expiration Date Plist

- (NSString*) expirationDateInfoPath
{
    if (!_expirationDateInfoPath)
    {
        _expirationDateInfoPath = [self.fileSystemPath stringByAppendingPathComponent:@"DownloadManagerExpirationDates.plist"];
    }
    return _expirationDateInfoPath;
}

- (BOOL) isValidElementAtPath:(NSString*)path
{
    if (!self.useHeadRequestToCheckUpdates)
    {
        // resources available in local are valid
        return YES;
    }
    
    if (!self.useExpirationDatePlist)
    {
        return NO;
    }
    
    NSDate* expirationDate = [self.expirationDateInfo objectForKey:path];
    BOOL isValid = NO;
    
    if (expirationDate && [expirationDate compare:[NSDate date]] == NSOrderedDescending)
    {
        isValid = YES;
    }
    
    return isValid;
}

// synchronize expiration date infos, deleting old entries
- (void) synchronizeCacheInfos
{
    if (self.useExpirationDatePlist)
    {
        self.expirationDateInfo = [NSMutableDictionary dictionaryWithContentsOfFile:self.expirationDateInfoPath];
        
        if (self.expirationDateInfo)
        {
            // Delete expired element from cache memory
            NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
            NSMutableArray* removedKeys = [[NSMutableArray alloc] init];
            
            for (NSString* key in self.expirationDateInfo)
            {
                if ([self.expirationDateInfo[key] timeIntervalSinceReferenceDate] <= now)
                {
                    [removedKeys addObject:key];
                }
            }
            [self.expirationDateInfo removeObjectsForKeys:removedKeys];
        }
        else
        {
            self.expirationDateInfo = [[NSMutableDictionary alloc] init];
        }
    }
}

// persist plist when app goes to background
- (void) writeExpirationDateInfoIntoPlist
{
    if (self.useExpirationDatePlist)
    {
        SDLogModuleInfo(kDownloadManagerLogModuleName, @"Salavataggio Expiration Date plist");
        
        __weak typeof(self)weakSelf = self;
        dispatch_async(expirationDateInfoQueue, ^{
            @try {
                [weakSelf.expirationDateInfo writeToFile:self.expirationDateInfoPath atomically:YES];
            }
            @catch (NSException* exception)
            {
                SDLogModuleError(kDownloadManagerLogModuleName, @"CacheInfo write error");
            }
            @finally
            {
            }
        });
    }
}

- (void) resetMemoryCache
{
    if (self.useExpirationDatePlist)
    {
        self.expirationDateInfo = [[NSMutableDictionary alloc] init];
        [self writeExpirationDateInfoIntoPlist];
    }
    
    if (self.useMemoryCache)
    {
        [self.memoryCache removeAllObjects];
    }
}

/**
 *  Purge all files from file system which are older than the given dates. Compares the actual date with the downloaded date
 *
 *  @param numdays num days for consider a local file old and eligible to purge
 */
- (void) purgeLocalFilesOlderThanNumDays:(NSUInteger)numdays
{
    NSTimeInterval interval = numdays * 24 * 60 * 60;
    NSDate* beforeDate = [NSDate dateWithTimeIntervalSinceNow:-interval];
    
    [DKRFileManager deleteFilesContentInDirectoryNamed:self.fileSystemPath withModifyDateBefore:beforeDate];
}

#pragma mark Local Resources

/**
 *  Get infos about local respurce saved at given path
 *
 *  @param numdays num days for consider a local file old and eligible to purge
 */

/**
 *  Get infos about local respurce saved at given path
 *
 *  @param path    local path for the rosource
 *  @param type    type of resource to cast before return it
 *  @param options options to use for retreiving
 *
 *  @return dictionary with infos about file (LOCAL_STORED_OBJECT), local path (LOCAL_STORED_PATH) and result type (DOWNLOAD_OPERATION_INFO_RESULT_TYPE)
 */

- (NSDictionary<NSString*, id>*) getLocalStoredObjectAtPath:(NSString*)path type:(DownloadOperationType)type options:(SDDownloadOptions*)options
{
    NSMutableDictionary* resourceInfo;
    NSString* resourceIdentifier = [path lastPathComponent];
    
    BOOL useMemoryCache = self.useMemoryCache && !options.saveDisabled;
    BOOL useFileSystem = self.useFileSystem && !options.saveDisabled;
    BOOL useBundle = options.useBundle;
    
    if (useBundle)
    {
        NSString* bundleFilePath = [self bundlePathForResourcePath:path];
        if (bundleFilePath)
        {
            id storedObject = [self getStoredResourceAtPath:bundleFilePath ofType:type];
            if (storedObject)
            {
                return @{
                         LOCAL_STORED_OBJECT : storedObject,
                         LOCAL_STORED_PATH : bundleFilePath,
                         DOWNLOAD_OPERATION_INFO_RESULT_TYPE : @(DownloadOperationResultBundleRetreived)
                         };
            }
        }
    }
    
    
    if (useMemoryCache)
    {
        // check if is in NSCache if should use memory cache
        resourceInfo = [self.memoryCache objectForKey:resourceIdentifier];
        [resourceInfo setObject:path forKey:LOCAL_STORED_PATH];
    }
    
    if (!resourceInfo && useFileSystem)
    {
        // if not find yet, check in File System
        id storedObject = [self getStoredResourceAtPath:path ofType:type];
        
        
        if (storedObject)
        {
            DKRFileInfo* fileInfo = [DKRFileManager getInfoAboutFileAtPath:path];
            NSDate* lastModifiedDate = fileInfo.modificationDateOnServer;
            
            resourceInfo = [[NSMutableDictionary alloc] init];
            if (lastModifiedDate)
            {
                [resourceInfo setObject:lastModifiedDate forKey:LOCAL_STORED_OBJECT_LAST_MODIFIED_DATE];
            }
            [resourceInfo setObject:storedObject forKey:LOCAL_STORED_OBJECT];
            [resourceInfo setObject:path forKey:LOCAL_STORED_PATH];
            
            if (useMemoryCache)
            {
                // once have resource set into memory cache if used
                [self.memoryCache setObject:resourceInfo forKey:resourceIdentifier];
            }
        }
    }
    
    return resourceInfo;
}

/**
 *  Get local resource saved into file system casting depending the specific type
 *
 *  @param path local path of resource
 *  @param type type to cast
 *
 *  @return hte casted resources (UIImage if type = DownloadOperationTypeImage), otherwise return NSData
 */
- (id) getStoredResourceAtPath:(NSString*)path ofType:(DownloadOperationType)type
{
    id storedObject;
    
    if (type == DownloadOperationTypeImage)
    {
        storedObject = [UIImage imageWithContentsOfFile:path];
    }
    else
    {
        storedObject = [NSData dataWithContentsOfFile:path];
    }
    return storedObject;
}

#pragma mark Utils

/**
 *  Return the local path where persist the resource at the given url. It will be used to retreive manually the resource or to check if is present locally (ex. [UIImage imageWithContentOFUrl: <this path>])
 *
 * Default: local path set in <fileSystemPath>/<MD5 of url>
 *
 *  @param urlString    url of the resource
 *
 *  @return path        local path where persist the resource
 */
- (NSString*) localResourcePathForUrlString:(NSString*)urlString
{
    NSString* identifier = [self localResourceIdentifierForUrlString:urlString];
    
    if (identifier)
    {
        NSString* path = [self.fileSystemPath stringByAppendingPathComponent:identifier];
        return path;
    }
    
    return nil;
}

- (NSString*) bundlePathForResourcePath:(NSString*)path
{
    NSString* identifier = [path lastPathComponent];
    
    if (identifier)
    {
        NSString* path = [self.bundlePath stringByAppendingPathComponent:identifier];
        return path;
    }
    
    return nil;
}

- (NSString*) localResourceIdentifierForUrlString:(NSString*)urlString
{
    NSString* uniquePath = [urlString.stringByDeletingLastPathComponent MD5String];
    NSString* url = [NSString stringWithFormat:@"%@_%@", uniquePath, urlString.lastPathComponent];
    
    return [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (long) downloadOperationRemainingQueueCount
{
    return self.downloadElementsOperations.count;
}

- (NSInteger) indexDownloadingElementsOperations:(NSString*)path
{
    for (NSInteger i = 0; i < self.downloadElementsOperations.count; i++)
    {
        AFHTTPRequestOperation* operation = self.downloadElementsOperations[i];
        
        if ([[operation.userInfo valueForKey:OPERATION_INFO_LOCAL_PATH] isEqualToString:path])
        {
            return i;
        }
    }
    return NSNotFound;
}

- (BOOL) downloadElementAlreadyQueued:(NSString*)path
{
    for (AFHTTPRequestOperation* operation in self.downloadRequestOperationManager.operationQueue.operations)
    {
        if ([[operation.userInfo valueForKey:OPERATION_INFO_LOCAL_PATH] isEqualToString:path])
        {
            return YES;
        }
    }
    return NO;
}

/**
 *  Add subscriber to keep handler for completion, failure and progress for a specific resource at given url. When something appened for the resource it will be fired the corresponding block
 *
 */
- (void) addSubscriberForUrl:(NSString*)urlString withCompletionSuccess:(SDDownloadManagerCompletionSuccessHandler)completionSuccess progress:(SDDownloadManagerProgressHandler)progress completionFailure:(SDDownloadManagerCompletionFailureHandler)completionFailure
{
    NSMutableArray* subscribersInfos = self.urlDownloadersDictionary[urlString];
    
    if (!subscribersInfos)
    {
        subscribersInfos = [NSMutableArray new];
        [self.urlDownloadersDictionary setObject:subscribersInfos forKey:urlString];
    }
    
    SDDownloadObjectInfo* info = [SDDownloadObjectInfo new];
    info.successHandler = completionSuccess;
    info.progressHandler = progress;
    info.failureHandler = completionFailure;
    
    [subscribersInfos addObject:info];
}

- (void) removeSubscribersForUrl:(NSString*)urlString
{
    [self.urlDownloadersDictionary removeObjectForKey:urlString];
}

#pragma mark - DOWNLOAD

- (void) downloadElement:(DownloadOperationType)elementType
             withRequest:(NSMutableURLRequest*)request
                 options:(SDDownloadOptions*)options
    lastModificationDate:(NSDate*)lastModificationDate
       completionSuccess:(SDDownloadManagerCompletionSuccessHandler)completionSuccess
                progress:(SDDownloadManagerProgressHandler)progress
       completionFailure:(SDDownloadManagerCompletionFailureHandler)completionFailure
{
    NSString* urlString = request.URL.absoluteString;
    
    if (urlString.length == 0 || options.localPath.length == 0)
    {
        SDLogModuleError(kDownloadManagerLogModuleName, @"SDDownloadManager: Impossible to download element with urlString NIL or localPath NIL: download not started.");
        return;
    }
    
    [self addSubscriberForUrl:urlString withCompletionSuccess:completionSuccess progress:progress completionFailure:completionFailure];
    
    if ([self downloadElementAlreadyQueued:options.localPath])
    {
        SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: element already queued for URL: %@", urlString);
        return;
    }
    
    BOOL forceDownload = options.forceDownload;
    if (forceDownload || !lastModificationDate)
    {
        SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: forced download from URL: %@ in local path %@", urlString, options.localPath);
        AFHTTPRequestOperation* downloadOperation = [self downloadOperationForElement:elementType withRequest:request overridingModificationDate:nil options:options];
        downloadOperation.securityPolicy.allowInvalidCertificates = _downloadRequestOperationManager.securityPolicy.allowInvalidCertificates;
        [self.downloadRequestOperationManager.operationQueue addOperation:downloadOperation];
    }
    else
    {
        AFHTTPRequestOperation* updateOperation = [self checkOperationForElement:elementType withRequest:request options:options lastModificationDate:lastModificationDate completionSuccess:completionSuccess progress:progress completionFailure:completionFailure];
        
        updateOperation.securityPolicy.allowInvalidCertificates = _downloadRequestOperationManager.securityPolicy.allowInvalidCertificates;
        
        [self.downloadRequestOperationManager.operationQueue addOperation:updateOperation];
    }
}

/**
 *  Check (HEAD) + download operation if needed
 */
- (AFHTTPRequestOperation*) checkOperationForElement:(DownloadOperationType)elementType
                                         withRequest:(NSMutableURLRequest*)request
                                             options:(SDDownloadOptions*)options
                                lastModificationDate:(NSDate*)lastModificationDate
                                   completionSuccess:(SDDownloadManagerCompletionSuccessHandler)completionSuccess
                                            progress:(SDDownloadManagerProgressHandler)progress
                                   completionFailure:(SDDownloadManagerCompletionFailureHandler)completionFailure

{
    NSMutableURLRequest* headRequest = [request mutableCopy];
    
    [headRequest setHTTPMethod:@"HEAD"];
    headRequest.timeoutInterval = self.timeoutInterval;
    
    NSString* urlString = request.URL.absoluteString;
    NSString* localPath = options.localPath;
    
    NSMutableDictionary* info = [[NSMutableDictionary alloc] init];
    if (!info)
    {
        info = [[NSMutableDictionary alloc] init];
    }
    [info setValue:localPath forKey:OPERATION_INFO_LOCAL_PATH];
    
    __weak typeof(self)weakSelf = self;
    
    AFHTTPRequestOperation* headOperation = [self.downloadRequestOperationManager HTTPRequestOperationWithRequest:headRequest success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
        NSDictionary* dictionary = [operation.response allHeaderFields];
        NSString* lastUpdated = [dictionary valueForKey:@"Last-Modified"];
        NSString* contentLenght = [dictionary valueForKey:@"Content-Length"];
        
        if (contentLenght.intValue < CONTENT_LENGTH_EMPTY_IMAGE)
        {
            SDLogModuleWarning(kDownloadManagerLogModuleName, @"SDDownloadManager: check update (head request) - resource empty or too small at URL: %@", urlString);
            NSDictionary* userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultDownloadedNewFailed) };
            
            [weakSelf manageFailureForDownloadOperation:operation error:nil type:elementType URL:urlString options:options userInfo:userInfo];
            
            return;
        }
        
        NSDate* lastUpdatedServer = [weakSelf.serverDateFormatter dateFromString:lastUpdated];
        
        BOOL needsDownload = !lastModificationDate || (lastUpdatedServer && ![lastUpdatedServer isEqualToDate:lastModificationDate]);
        
        if (needsDownload)
        {
            SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: check update (head request) - local resource NOT updated, need download from URL: %@ in local path %@", urlString, localPath);
            AFHTTPRequestOperation* downloadOperation = [weakSelf downloadOperationForElement:elementType withRequest:request overridingModificationDate:lastUpdatedServer options:options];
            
            [weakSelf.downloadRequestOperationManager.operationQueue addOperation:downloadOperation];
        }
        else
        {
            SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: check update (head request) - local resource UPDATED, download not required from URL: %@", urlString);
            
            NSDictionary* userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultLoadLocallyCheckingValidSuccessed) };
            
            [weakSelf manageSuccessForDownloadOperation:operation result:nil type:elementType URL:urlString options:options lastModifiedDate:lastModificationDate userInfo:userInfo];
        }
    } failure:^(AFHTTPRequestOperation* _Nonnull operation, NSError* _Nonnull error) {
        SDLogModuleError(kDownloadManagerLogModuleName, @"SDDownloadManager: check update (head request) - failed checking resource validity from URL: %@\n\nError: %@\n%@", urlString, error, [error userInfo]);
        
        NSDictionary* userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultLoadLocallyCheckingValidFailed) };
        
        [weakSelf manageSuccessForDownloadOperation:operation result:nil type:elementType URL:urlString options:options lastModifiedDate:lastModificationDate userInfo:userInfo];
    }];
    
    headOperation.userInfo = [NSDictionary dictionaryWithDictionary:info];
    
    return headOperation;
}

/**
 *  Download operation
 */
- (AFHTTPRequestOperation*) downloadOperationForElement:(DownloadOperationType)elementType
                                            withRequest:(NSURLRequest*)request
                             overridingModificationDate:(NSDate*)modificationDate
                                                options:(SDDownloadOptions*)options
{
    NSString* urlString = request.URL.absoluteString;
    NSString* localPath = options.localPath;
    
    __weak typeof(self)weakSelf = self;
    
    // Download file in a temporary path so that if download is interrupted (ex. app killed) there will not be a corrupted file that will be consider good at the final local path
    NSString* tmpPath = [localPath stringByAppendingString:@"_tmp"];
    
    AFHTTPRequestOperation* downloadOperation = [self.downloadRequestOperationManager HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
        // Delete file at local path before coping the temporary to it (otherwise if already exist a file it will fail)
        [DKRFileManager deleteFilesAtPath:localPath];
        
        NSError* error = nil;
        BOOL copy = [[NSFileManager defaultManager] moveItemAtPath:tmpPath toPath:localPath error:&error];
        if (copy && !error)
        {
            // Last modification date is the server one (not the local one)
            NSDate* lastUpdatedServer;
            if (!modificationDate)
            {
                NSDictionary* dictionary = [operation.response allHeaderFields];
                NSString* contentLenght = [dictionary valueForKey:@"Content-Length"];
                
                if (contentLenght.intValue < CONTENT_LENGTH_EMPTY_IMAGE)
                {
                    SDLogModuleWarning(kDownloadManagerLogModuleName, @"SDDownloadManager: download new - resource empty or too small at URL: %@", urlString);
                    NSDictionary* userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultDownloadedNewFailed) };
                    [weakSelf manageFailureForDownloadOperation:operation error:nil type:elementType URL:urlString options:options userInfo:userInfo];
                    return;
                }
                
                NSString* lastUpdated = [dictionary valueForKey:@"Last-Modified"];
                lastUpdatedServer = [weakSelf.serverDateFormatter dateFromString:lastUpdated];
                if (!lastUpdatedServer)
                {
                    lastUpdatedServer = [NSDate date];
                }
            }
            
            SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: download new - resource download with success from URL: %@ in local path %@", urlString, localPath);
            
            // set server date if exist so that it could be compare next with head requests
            NSDate* modificationDateOnServer = modificationDate ? modificationDate : lastUpdatedServer;
            if (!modificationDateOnServer)
            {
                modificationDateOnServer = [NSDate date];
            }
            
            NSDictionary* userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultDownloadedNew) };
            [weakSelf manageSuccessForDownloadOperation:operation result:responseObject type:elementType URL:urlString options:options lastModifiedDate:modificationDateOnServer userInfo:userInfo];
        }
        else
        {
            SDLogModuleError(kDownloadManagerLogModuleName, @"SDDownloadManager: erro while moving resource from %@ to %@.\n\nError: %@", tmpPath, localPath, error.localizedDescription);
            [DKRFileManager deleteFilesAtPath:tmpPath];
        }
    } failure:^(AFHTTPRequestOperation* _Nonnull operation, NSError* _Nonnull error) {
        [DKRFileManager deleteFilesAtPath:tmpPath];
        
        SDLogModuleError(kDownloadManagerLogModuleName, @"SDDownloadManager: download new - error while downloading resource from URL: %@ to local path %@\n\nError: %@\n%@", urlString, localPath, error, [error userInfo]);
        NSDictionary* userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultDownloadedNewFailed) };
        
        [weakSelf manageFailureForDownloadOperation:operation error:error type:elementType URL:urlString options:options userInfo:userInfo];
    }];
    
    downloadOperation.queuePriority = NSOperationQueuePriorityNormal;
    if ([downloadOperation respondsToSelector:@selector(setQualityOfService:)])
    {
        downloadOperation.qualityOfService = NSQualityOfServiceUserInteractive;
    }
    
    downloadOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:tmpPath append:NO];
    
    NSMutableDictionary* info = [[NSMutableDictionary alloc] init];
    [info setValue:localPath forKey:OPERATION_INFO_LOCAL_PATH];
    [info setValue:options forKey:OPERATION_INFO_OPTIONS];
    downloadOperation.userInfo = info;
    
    [downloadOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead)
     {
         [weakSelf manageProgressForDownloadOperationWithURL:urlString bytesRead:bytesRead totalBytesRead:totalBytesRead totalBytesExpectedToRead:totalBytesExpectedToRead];
     }];
    
    return downloadOperation;
}

#pragma mark - COMMON DOWNLOAD CALLBACK

- (void) manageSuccessForDownloadOperation:(AFHTTPRequestOperation*)operation
                                    result:(id)result
                                      type:(DownloadOperationType)type
                                       URL:(NSString*)urlString
                                   options:(SDDownloadOptions*)options
                          lastModifiedDate:(NSDate*)lastModifiedDate
                                  userInfo:(NSDictionary*)userInfo
{
    NSString* localPath = options.localPath;
    
    if (localPath)
    {
        NSInteger index = [self indexDownloadingElementsOperations:localPath];
        if (index != NSNotFound && self.downloadElementsProcessing)
        {
            // Remove operation when completed
            [self.downloadElementsOperations removeObjectAtIndex:index];
            [self.downloadElementsSizeInfos removeObjectForKey:urlString];
            
            if (self.downloadElementsProgressHandler)
            {
                self.downloadElementsProgressHandler(self.downloadElementsExpectedTotalSize, self.downloadElementsRemainingSize, self.downloadOperationExpectedQueueCount, self.downloadOperationRemainingQueueCount);
            }
        }
    }
    
    // check if empty queue to fire events
    [self checkEmptyQueue];
    
    id downloadedObject;
    NSTimeInterval expirationInterval = options.expirationInterval;
    if (localPath)
    {
        NSString* resourceIdentifier = [localPath lastPathComponent];
        
        BOOL useFileSystem = self.useFileSystem && !options.saveDisabled;
        BOOL useMemoryCache = self.useMemoryCache && !options.saveDisabled;
        
        
        // save expiration date in plist file
        if ((useFileSystem || useMemoryCache) && self.useExpirationDatePlist && expirationInterval > 0)
        {
            NSDate* expirationDate = [NSDate dateWithTimeIntervalSinceNow:expirationInterval];
            [self.expirationDateInfo setObject:expirationDate forKey:resourceIdentifier];
        }
        
        // retreive resource from local path
        downloadedObject = [self getStoredResourceAtPath:localPath ofType:type];
        
        if (useFileSystem)
        {
            if (lastModifiedDate)
            {
                // save info about last modification date usign the server date (this info will be used next to check the updated status)
                NSError* error = nil;
                NSMutableDictionary* attrs = [[[NSFileManager defaultManager] attributesOfItemAtPath:localPath error:&error] mutableCopy];
                if (!error)
                {
                    [attrs setObject:lastModifiedDate forKey:NSFileCreationDate];
                    [attrs setObject:[NSDate date] forKey:NSFileModificationDate];
                    [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:localPath error:NULL];
                }
            }
        }
        else
        {
            // if shouldn't be saved into file system, delete from local path
            [DKRFileManager deleteFilesAtPath:localPath];
        }
        
        if (useMemoryCache)
        {
            NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
            if (lastModifiedDate)
            {
                [dict setObject:lastModifiedDate forKey:LOCAL_STORED_OBJECT_LAST_MODIFIED_DATE];
            }
            if (downloadedObject)
            {
                [dict setObject:downloadedObject forKey:LOCAL_STORED_OBJECT];
            }
            [self.memoryCache setObject:dict forKey:resourceIdentifier];
        }
        else
        {
            [self.memoryCache removeObjectForKey:resourceIdentifier];
        }
    }
    
    DownloadOperationResultType resultType = [(NSNumber*) userInfo[DOWNLOAD_OPERATION_INFO_RESULT_TYPE] integerValue];
    
    BOOL notifyCheckingValidity = options.notifyBeforeValidityCheck;
    if (!notifyCheckingValidity && resultType == DownloadOperationResultLoadLocallyCheckingValid)
    {
        // should not notify, because resource is temporary (there will be un update)
        return;
    }
    
    // notifies all subscribers for the downloaded url
    NSMutableArray<SDDownloadObjectInfo*>* subscribers = self.urlDownloadersDictionary[urlString];
    for (SDDownloadObjectInfo* info in subscribers)
    {
        if (info.successHandler)
        {
            info.successHandler(downloadedObject, urlString, localPath, resultType);
        }
    }
    
    if (resultType != DownloadOperationResultLoadLocallyCheckingValid)
    {
        [self removeSubscribersForUrl:urlString];
    }
}

- (void) manageFailureForDownloadOperation:(AFHTTPRequestOperation*)operation
                                     error:(NSError*)error
                                      type:(DownloadOperationType)type
                                       URL:(NSString*)urlString
                                   options:(SDDownloadOptions*)options
                                  userInfo:(NSDictionary*)userInfo
{
    [self checkEmptyQueue];
    
    DownloadOperationResultType resultType = [(NSNumber*) userInfo[DOWNLOAD_OPERATION_INFO_RESULT_TYPE] integerValue];
    NSString* localPath = options.localPath;
    
    if (localPath && resultType == DownloadOperationResultDownloadedNewFailed)
    {
        // rimuovo il file solo se è stato tentato un nuovo download ed è fallito (altrimenti tengo il file locale)
        BOOL useFileSystem = self.useFileSystem && !options.saveDisabled;
        BOOL useMemoryCache = self.useMemoryCache && !options.saveDisabled;
        
        if (useFileSystem)
        {
            [DKRFileManager deleteFilesAtPath:localPath];
        }
        
        if (useMemoryCache)
        {
            NSString* resourceIdentifier = [localPath lastPathComponent];
            [self.memoryCache removeObjectForKey:resourceIdentifier];
        }
    }
    
    // re-add downloaded size for operation failed
    if (self.downloadElementsProcessing)
    {
        SDDownloadStatistic* statistic = self.downloadElementsSizeInfos[urlString];
        long long downloadedSize = statistic.totalSizeExpected - statistic.sizeRemaining;
        
        self.downloadElementsRemainingSize += downloadedSize;
    }
    
    
    // notifies all subscribers for the downloaded url
    NSMutableArray<SDDownloadObjectInfo*>* subscribers = self.urlDownloadersDictionary[urlString];
    for (SDDownloadObjectInfo* info in subscribers)
    {
        if (info.failureHandler)
        {
            info.failureHandler(urlString, error);
        }
    }
    [self removeSubscribersForUrl:urlString];
}

- (void) manageProgressForDownloadOperationWithURL:(NSString*)urlString
                                         bytesRead:(NSUInteger)bytesRead totalBytesRead:(long long)totalBytesRead
                          totalBytesExpectedToRead:(long long)totalBytesExpectedToRead
{
    // update the remaining size if the download batch is processing and calls the progress handler
    if (self.downloadElementsProcessing)
    {
        self.downloadElementsRemainingSize -= bytesRead;
        
        SDDownloadStatistic* statistic = self.downloadElementsSizeInfos[urlString];
        statistic.sizeRemaining -= bytesRead;
    }
    if (self.downloadElementsProgressHandler)
    {
        self.downloadElementsProgressHandler(self.downloadElementsExpectedTotalSize, self.downloadElementsRemainingSize, self.downloadOperationExpectedQueueCount, self.downloadOperationRemainingQueueCount);
    }
    
    // call the progress handler for the all subscribers for the specific url
    NSMutableArray<SDDownloadObjectInfo*>* subscribers = self.urlDownloadersDictionary[urlString];
    for (SDDownloadObjectInfo* info in subscribers)
    {
        if (info.progressHandler)
        {
            info.progressHandler(urlString, bytesRead, totalBytesRead, totalBytesExpectedToRead);
        }
    }
}

- (void) checkEmptyQueue
{
    // use a timer to wait and be sure about the empty queue
    __weak typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [timerEmptyQueueNotification invalidate];
        if (weakSelf.downloadRequestOperationManager.operationQueue.operationCount == 0)
        {
            if (weakSelf.downloadElementsProcessing && self.downloadElementsOperations.count == 0)
            {
                [weakSelf synchronizeCacheInfos];
            }
            
            timerEmptyQueueNotification = [NSTimer scheduledTimerWithTimeInterval:1 target:weakSelf selector:@selector(notifyEmptyQueue) userInfo:nil repeats:NO];
        }
    });
}

- (void) notifyEmptyQueue
{
    // fire the check size completion
    if (self.checkSizeElementsProcessing)
    {
        if (self.checkSizeCompletion)
        {
            self.checkSizeCompletion(self.downloadElementsExpectedTotalSize, self.downloadOperationExpectedQueueCount);
            self.checkSizeCompletion = nil;
        }
        self.checkSizeProgressHandler = nil;
        self.checkSizeElementsProcessing = NO;
    }
    
    // fire the download completion
    if (self.downloadElementsProcessing)
    {
        if (self.downloadElementsCompletionHandler)
        {
            BOOL downloadCompleted = self.downloadElementsOperations.count == 0;
            self.downloadElementsCompletionHandler(downloadCompleted);
            self.downloadElementsCompletionHandler = nil;
        }
        self.downloadElementsProgressHandler = nil;
        self.downloadElementsProcessing = NO;
    }
}

#pragma mark Cancel Requests

- (void) cancelAllDownloadRequests
{
    for (NSOperation* operation in[self.downloadRequestOperationManager.operationQueue operations])
    {
        if (![operation isKindOfClass:[AFHTTPRequestOperation class]])
        {
            continue;
        }
        [operation cancel];
    }
}

#pragma mark Resource Download

- (void) getResourceAtUrl:(NSString*)urlString completionSuccess:(SDDownloadManagerCompletionSuccessHandler)completionSuccess progress:(SDDownloadManagerProgressHandler)progress completionFailure:(SDDownloadManagerCompletionFailureHandler)completionFailure
{
    [self getResourceAtUrl:urlString type:DownloadOperationTypeGeneric options:nil completionSuccess:completionSuccess progress:progress completionFailure:completionFailure];
}

- (void) getResourceAtUrl:(NSString*)urlString type:(DownloadOperationType)type options:(SDDownloadOptions*)options completionSuccess:(SDDownloadManagerCompletionSuccessHandler)completionSuccess progress:(SDDownloadManagerProgressHandler)progress completionFailure:(SDDownloadManagerCompletionFailureHandler)completionFailure
{
    if (!urlString || urlString.length == 0)
    {
        return;
    }
    
    NSURL* url = [self encodedUrlFromString:urlString];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = self.timeoutInterval;
    
    [self getResourceWithRequest:request type:type options:options completionSuccess:completionSuccess progress:progress completionFailure:completionFailure];
}

- (void) getResourceWithRequest:(NSMutableURLRequest*)request completionSuccess:(SDDownloadManagerCompletionSuccessHandler)completionSuccess progress:(SDDownloadManagerProgressHandler)progress completionFailure:(SDDownloadManagerCompletionFailureHandler)completionFailure
{
    [self getResourceWithRequest:request type:DownloadOperationTypeGeneric options:nil completionSuccess:completionSuccess progress:progress completionFailure:completionFailure];
}

// Start retreiving resource: it will search before locally depending of options and default settings
- (void) getResourceWithRequest:(NSMutableURLRequest*)request
                           type:(DownloadOperationType)type
                        options:(SDDownloadOptions*)downloadOptions
              completionSuccess:(SDDownloadManagerCompletionSuccessHandler)completionSuccess
                       progress:(SDDownloadManagerProgressHandler)progress
              completionFailure:(SDDownloadManagerCompletionFailureHandler)completionFailure
{
    __block SDDownloadOptions* options = downloadOptions;
    
    __weak typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if (!options)
        {
            options = [SDDownloadOptions new];
        }
        
        NSString* urlString = request.URL.absoluteString;
        
        
        NSString* localPath = options.localPath;
        if (!localPath)
        {
            localPath = [weakSelf localResourcePathForUrlString:urlString];
            options.localPath = localPath;
        }
        else
        {
            // create directory if needed
            NSString* directoryPath = [localPath stringByDeletingLastPathComponent];
            if (directoryPath.length > 0)
            {
                [DKRFileManager createDirectoryForFileAtPathIfNeeded:directoryPath];
            }
        }
        
        // check if start download immediately (forced download) or try retreiving file locally (if already downloaded before)
        BOOL forceDownload = options.forceDownload;
        if (!forceDownload)
        {
            NSDictionary* localStoredResourceInfo = [weakSelf getLocalStoredObjectAtPath:localPath type:type options:options];
            id storedResource = [localStoredResourceInfo objectForKey:LOCAL_STORED_OBJECT];
            
            if (storedResource)
            {
                NSDictionary* userInfo;
                
                DownloadOperationResultType resultType = [(NSNumber*) localStoredResourceInfo[DOWNLOAD_OPERATION_INFO_RESULT_TYPE] integerValue];
                localPath = localStoredResourceInfo[LOCAL_STORED_PATH];
                
                // check if exists in bundle
                if (resultType == DownloadOperationResultBundleRetreived)
                {
                    userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultBundleRetreived) };
                }
                else
                {
                    // check if expired
                    NSString* resourceIdentifier = [localPath lastPathComponent];
                    if ([weakSelf isValidElementAtPath:resourceIdentifier])
                    {
                        userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultLoadLocallyStillValid) };
                    }
                    else
                    {
                        userInfo = @{ DOWNLOAD_OPERATION_INFO_RESULT_TYPE:@(DownloadOperationResultLoadLocallyCheckingValid) };
                        
                        [weakSelf.expirationDateInfo removeObjectForKey:localPath];
                        
                        NSDate* lastModifiedDate = [localStoredResourceInfo objectForKey:LOCAL_STORED_OBJECT_LAST_MODIFIED_DATE];
                        
                        [weakSelf downloadElement:type withRequest:request options:options lastModificationDate:lastModifiedDate completionSuccess:completionSuccess progress:progress completionFailure:completionFailure];
                    }
                }
                
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    DownloadOperationResultType resultType = [(NSNumber*) userInfo[DOWNLOAD_OPERATION_INFO_RESULT_TYPE] integerValue];
                    
                    BOOL notifyCheckingValidity = options.notifyBeforeValidityCheck;
                    if (!notifyCheckingValidity && resultType == DownloadOperationResultLoadLocallyCheckingValid)
                    {
                        // should not notify, because resource is temporary (there will be un update)
                        return;
                    }
                    
                    if (completionSuccess)
                    {
                        completionSuccess(storedResource, urlString, localPath, resultType);
                    }
                });
                
                return;
            }
            else
            {
                options.forceDownload = YES;
            }
        }
        
        [weakSelf downloadElement:type withRequest:request options:options lastModificationDate:nil completionSuccess:completionSuccess progress:progress completionFailure:completionFailure];
    });
}

#pragma mark - COUNT DOWNLOAD

- (void) downloadAllElementsCheckedWithProgress:(SDDownloadManagerBatchOperationProgressHandler)progress completion:(SDDownloadManagerBatchOperationCompletion)completion
{
    if (self.downloadElementsProcessing)
    {
        SDLogModuleWarning(kDownloadManagerLogModuleName, @"SDDownloadManager: download batch already started, wait untill end before starting a new batch...");
        return;
    }
    
    self.downloadElementsProcessing = YES;
    self.downloadElementsProgressHandler = progress;
    self.downloadElementsCompletionHandler = completion;
    
    
    if (self.downloadElementsOperations.count == 0)
    {
        [self checkEmptyQueue];
        
        return;
    }
    
    SDLogModuleInfo(kDownloadManagerLogModuleName, @"SDDownloadManager: download batch started for %d resources with total size %.3f MB", (int)self.downloadElementsOperations.count, self.downloadElementsRemainingSize / (1024.*1024.));
    
    for (AFHTTPRequestOperation* downloadOperation in self.downloadElementsOperations)
    {
        AFHTTPRequestOperation* operation;
        if(downloadOperation.isFinished)
        {
            SDDownloadOptions* options = downloadOperation.userInfo[OPERATION_INFO_OPTIONS];
            operation = [self downloadOperationForElement:DownloadOperationTypeGeneric withRequest:downloadOperation.request overridingModificationDate:nil options:options];
        }
        else
        {
            operation = downloadOperation;
        }
         [self.downloadRequestOperationManager.operationQueue addOperation:operation];
    }
}

- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>*)urlStrings completion:(SDDownloadManagerCheckSizeCompletion)completion
{
    [self countDownloadSizeForResourceAtUrls:urlStrings options:nil completion:completion];
}

- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>*)urlStrings options:(SDDownloadOptions*)options completion:(SDDownloadManagerCheckSizeCompletion)completion
{
    [self countDownloadSizeForResourceAtUrls:urlStrings options:options progress:nil completion:completion];
}

- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>*)urlStrings options:(SDDownloadOptions*)options progress:(SDDownloadManagerCheckSizeCompletion)progress completion:(SDDownloadManagerCheckSizeCompletion)completion
{
    self.checkSizeElementsProcessing = YES;
    self.checkSizeCompletion = completion;
    self.checkSizeProgressHandler = progress;
    
    [self.downloadElementsOperations removeAllObjects];
    [self.downloadElementsSizeInfos removeAllObjects];
    self.downloadElementsExpectedTotalSize = 0;
    self.downloadElementsRemainingSize = 0;
    self.downloadOperationExpectedQueueCount = 0;
    
    for (NSString* urlString in urlStrings)
    {
        NSURL* url = [self encodedUrlFromString:urlString];
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
        request.timeoutInterval = self.timeoutInterval;
        
        [self countDownloadSizeForWithRequest:request options:options];
    }
}

- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>*)requests completion:(SDDownloadManagerCheckSizeCompletion)completion
{
    [self countDownloadSizeForResourceWithRequests:requests options:nil completion:completion];
}

- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>*)requests options:(SDDownloadOptions*)options completion:(SDDownloadManagerCheckSizeCompletion)completion
{
    [self countDownloadSizeForResourceWithRequests:requests options:options progress:nil completion:completion];
}

- (void) countDownloadSizeForResourceWithRequests:(NSArray<NSMutableURLRequest*>*)requests options:(SDDownloadOptions*)options progress:(SDDownloadManagerCheckSizeCompletion)progress completion:(SDDownloadManagerCheckSizeCompletion)completion
{
    if (!options)
    {
        options = [SDDownloadOptions new];
    }
    
    self.checkSizeElementsProcessing = YES;
    self.checkSizeCompletion = completion;
    self.checkSizeProgressHandler = progress;
    
    [self.downloadElementsOperations removeAllObjects];
    [self.downloadElementsSizeInfos removeAllObjects];
    self.downloadElementsExpectedTotalSize = 0;
    self.downloadElementsRemainingSize = 0;
    self.downloadOperationExpectedQueueCount = 0;
    
    for (NSMutableURLRequest* request in requests)
    {
        [self countDownloadSizeForWithRequest:request options:options];
    }
}

- (void) countDownloadSizeForWithRequest:(NSMutableURLRequest*)request
                                 options:(SDDownloadOptions*)downloadOptions
{
    __block SDDownloadOptions* options = downloadOptions;
    
    __weak typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString* urlString = request.URL.absoluteString;
        
        if (!options)
        {
            options = [SDDownloadOptions new];
        }
        
        NSString* localPath = options.localPath;
        if (!localPath)
        {
            localPath = [weakSelf localResourcePathForUrlString:urlString];
            options.localPath = localPath;
        }
        
        if ([weakSelf downloadElementAlreadyQueued:localPath])
        {
            SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: check size resource already queued for URL:%@", urlString);
            return;
        }
        
        
        NSDictionary* localStoredResourceInfo = [weakSelf getLocalStoredObjectAtPath:localPath type:DownloadOperationTypeGeneric options:options];
        id storedResource = [localStoredResourceInfo objectForKey:LOCAL_STORED_OBJECT];
        NSDate* lastModifiedDate;
        
        if (storedResource)
        {
            DownloadOperationResultType resultType = [(NSNumber*) localStoredResourceInfo[DOWNLOAD_OPERATION_INFO_RESULT_TYPE] integerValue];
            
            // chek if retreived from bundle
            if (resultType == DownloadOperationResultBundleRetreived)
            {
                [weakSelf checkEmptyQueue];
                return;
            }
            
            // Search if is expired
            NSString* resourceIdentifier = [localPath lastPathComponent];
            if ([weakSelf isValidElementAtPath:resourceIdentifier])
            {
                [weakSelf checkEmptyQueue];
                return;
            }
            else
            {
                [weakSelf.expirationDateInfo removeObjectForKey:localPath];
                
                lastModifiedDate = [localStoredResourceInfo objectForKey:LOCAL_STORED_OBJECT_LAST_MODIFIED_DATE];
            }
        }
        
        AFHTTPRequestOperation* updateOperation =  [weakSelf checkSizeOperationForElement:DownloadOperationTypeGeneric withRequest:request lastModificationDate:lastModifiedDate options:options ];
        
        updateOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
        [weakSelf.downloadRequestOperationManager.operationQueue addOperation:updateOperation];
    });
}

/**
 *  Check size (HEAD) + elementsToDownloadSize increment + add to downloadElementsOperations
 */


- (AFHTTPRequestOperation*) checkSizeOperationForElement:(DownloadOperationType)elementType
                                             withRequest:(NSMutableURLRequest*)request
                                    lastModificationDate:(NSDate*)lastModificationDate
                                                 options:(SDDownloadOptions*)options
{
    NSString* localPath = options.localPath;
    NSMutableURLRequest* headRequest = [request mutableCopy];
    
    [headRequest setHTTPMethod:@"HEAD"];
    
    NSMutableDictionary* info = [[NSMutableDictionary alloc] init];
    if (!info)
    {
        info = [[NSMutableDictionary alloc] init];
    }
    [info setValue:localPath forKey:OPERATION_INFO_LOCAL_PATH];
    
    __weak typeof(self)weakSelf = self;
    
    NSString* urlString = request.URL.absoluteString;
    
    AFHTTPRequestOperation* headOperation = [self.downloadRequestOperationManager HTTPRequestOperationWithRequest:headRequest success:^(AFHTTPRequestOperation* _Nonnull operation, id _Nonnull responseObject) {
        NSDictionary* dictionary = [operation.response allHeaderFields];
        NSString* lastUpdated = [dictionary valueForKey:@"Last-Modified"];
        
        
        NSDate* lastUpdatedServer = [weakSelf.serverDateFormatter dateFromString:lastUpdated];
        
        BOOL needsDownload = !lastModificationDate || (lastUpdatedServer && ![lastUpdatedServer isEqualToDate:lastModificationDate]);
        
        // If needs to be downloaded: increments the elementsToDownloadSize and add proper operation to downloadElementsOperations.
        if (needsDownload)
        {
            SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: check size - local resource NOT updated, need download from URL: %@ in local path %@", urlString, localPath);
            NSString* elementSize = [dictionary valueForKey:@"Content-Length"]; // dimension in byte
            double elementSizeValue = elementSize.doubleValue;
            
            
            
            if ([weakSelf indexDownloadingElementsOperations:localPath] == NSNotFound && elementSizeValue > 0)
            {
                AFHTTPRequestOperation* downloadOperation = [weakSelf downloadOperationForElement:elementType withRequest:request overridingModificationDate:lastUpdatedServer options:options];
                
                
                [weakSelf.downloadElementsOperations addObject:downloadOperation];
                weakSelf.downloadOperationExpectedQueueCount = weakSelf.downloadElementsOperations.count;
                
                BOOL resourceAlreadyChecked = weakSelf.downloadElementsSizeInfos[urlString] != nil;
                if(!resourceAlreadyChecked)
                {
                    weakSelf.downloadElementsExpectedTotalSize += elementSizeValue;
                    weakSelf.downloadElementsRemainingSize = weakSelf.downloadElementsExpectedTotalSize;
                    
                    SDDownloadStatistic* statistic = [SDDownloadStatistic new];
                    statistic.totalSizeExpected = elementSizeValue;
                    statistic.sizeRemaining = elementSizeValue;
                    
                    [weakSelf.downloadElementsSizeInfos setObject:statistic forKey:urlString];
                }
                
                if (weakSelf.checkSizeProgressHandler)
                {
                    weakSelf.checkSizeProgressHandler(weakSelf.downloadElementsExpectedTotalSize, weakSelf.downloadOperationExpectedQueueCount);
                }
            }
            else
            {
                if (elementSizeValue == 0)
                {
                    SDLogModuleWarning(kDownloadManagerLogModuleName, @"SDDownloadManager: check size - Server DOESN'T provide infos about Content-Lenght, therefore elements will not be count and queue for nex download. URL: %@", urlString);
                }
            }
            [weakSelf checkEmptyQueue];
        }
        else
        {
            SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadManager: check size - local resource UPDATED, download not required from URL: %@", urlString);
            
            [weakSelf checkEmptyQueue];
        }
    } failure:^(AFHTTPRequestOperation* _Nonnull operation, NSError* _Nonnull error) {
        SDLogModuleError(kDownloadManagerLogModuleName, @"SDDownloadManager: check size - failure checking size for resource at URL: %@\n\nError: %@\n%@", urlString, error, [error userInfo]);
        
        [weakSelf manageFailureForDownloadOperation:operation error:error type:elementType URL:urlString options:options userInfo:nil];
    }];
    
    headOperation.userInfo = info;
    
    return headOperation;
}

#pragma mark Utils

- (NSURL*) encodedUrlFromString:(NSString*)urlString
{
    NSURL* url = [[NSURL alloc] initWithString:[urlString stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];
    
    return url;
}

#pragma mark NSCacheDelegate

- (void) cache:(NSCache*)cache willEvictObject:(id)obj
{
    SDLogModuleVerbose(kDownloadManagerLogModuleName, @"NSCache will evict: %@", obj);
}

@end
