Docker
======

[![Version](https://img.shields.io/cocoapods/v/Docker.svg?style=flat)](http://cocoapods.org/pods/Docker)
[![License](https://img.shields.io/cocoapods/l/Docker.svg?style=flat)](http://cocoapods.org/pods/Docker)
[![Platform](https://img.shields.io/cocoapods/p/Docker.svg?style=flat)](http://cocoapods.org/pods/Docker)

![](https://github.com/SysdataSpA/Docker/blob/develop/docker_example.gif)

Example
-------

To run the example project, clone the repo, and run `pod install` from the
Example directory first.

Requirements
------------

iOS 8 and above, AFNetworking 2.6.3 (as pod dependency)

Installation
------------

Docker is available through [CocoaPods](http://cocoapods.org). To install it,
simply add the following line to your Podfile:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ruby
pod 'Docker'
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you want to use our logger framework Blabber, use subpod

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pod 'Docker/Blabber'
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

With Blabber you can manage all log messages or use CocoaLumberjack. In this
case import also the corresponding subpod. [See
more](https://github.com/SysdataSpA/Blabber) details...

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pod 'Docker/Blabber'
pod 'Blabber/CocoaLumberjack'
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

License
-------

Docker is available under the Apache license. See the LICENSE file for more
info.

Introduction
------------

Docker is a library that could be use to manage all communications with remote
servers in easy way. Docker is composed by two modules.

-   [SDServiceManager](#SDServiceManager): to handle web service calls

-   [SDDownloadManager](#SDDownloadManager): to handle resources download and
    local caching

Service Manager
===============

**SDServiceManager** is the base class that handle web service calls. There's a
**sharedServiceManager** as singleton, that can be used to call and manage all
services that your app requires. SDServiceManager should never be used directly,
but it's suggested to subclass it.

#### Main features:

-   easy define of **request** (headers, parameters, HTTP method, base url,
    relative path)

-   easy define of **response and error** class and mapping

-   service in **demo mode** (test your service with static JSON files in your
    bundle)

    -   simulate random time of interval in given range

    -   simulate success response

    -   simulate error response, HTTP status code with given probability of
        failure

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@interface MyServiceManager : SDServiceManager


- (void) callServiceForNumUsers:(NSNumber*)num withCompletion:(ServiceCompletionSuccessHandler)completion failure:(ServiceCompletionFailureHandler)failure;

@end
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**SDServiceManager** use **AFNetworking** framework (version 2.0), so you should
define **AFHTTPRequestOperationManager** to call services. In the initialization
define your base service url in the **defaultRequestOperationManager**. If you
need (ex. your application communicates with different web services) you can
instantiate different requestOperationManager and assign them to the each
specific server.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@implementation MyServiceManager

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.defaultRequestOperationManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://randomuser.me"]];
        self.defaultRequestOperationManager.requestSerializer = [AFJSONRequestSerializer serializer];
        self.defaultRequestOperationManager.requestSerializer.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", nil];
        self.defaultRequestOperationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    return self;
}


- (void) callServiceForNumUsers:(NSNumber*)num withCompletion:(ServiceCompletionSuccessHandler)completion failure:(ServiceCompletionFailureHandler)failure
{
    SDServiceExample* service = [SDServiceExample new];
    SDServiceExampleRequest* request = [SDServiceExampleRequest new];
    request.numUsers = num;
    
    [self callService:service withRequest:request operationType:0 delegate:nil completionSuccess:completion completionFailure:failure];
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Each web service *should be a subclass of SDServiceGeneric* and should implement
his protocols to define request, response and error behaviours. If your service
has an *application/json* content-type, you can subclass **SDServiceMantle**
that use Mantle framework to define the json mapping and value transformers.

In the example above you can see the define of the Service, the Request and the
expectedResponse of a service.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In your Service implementation you should define:

-   the **request operation manager** that will be used

-   the **relative path** of the resource

-   the **HTTP method**

-   the **response class** that will map the response in case of success

-   the **error class** that will map the response in case of failure

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@implementation SDServiceExample

- (AFHTTPRequestOperationManager *)requestOperationManager
{
    return [MyServiceManager sharedServiceManager].defaultRequestOperationManager;
}

- (NSString*) pathResource
{
    return @"/api";
}


- (SDHTTPMethod) requestMethodType
{
    return SDHTTPMethodGET;
}

- (Class) responseClass
{
    return [SDServiceExampleResponse class];
}

@end
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In your Request, Response and Error class you should define the mapping for each
property. Ex, using Mantle

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@implementation SDServiceExampleResponse

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return @{
             @"users":@"results"
            };
}

+ (NSValueTransformer*) usersJSONTransformer
{
    return [MTLJSONAdapter arrayTransformerWithModelClass:[MTLUser class]];
}

@end

@implementation MTLUser

+ (NSDictionary*) JSONKeyPathsByPropertyKey
{
    return @{
              @"firstName":@"name.first",
              @"lastName":@"name.last",
              @"imageUrl":@"picture.medium"
            };
}


@end
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For more details visit - **SDServiceGenericProtocol** to define all details of
service (ex. also the local json to test it in demo mode) -
**SDServiceGenericRequestProtocol** to define details about the request -
**SDServiceGenericResponsable** to define details about the response -
**SDServiceGenericErrorProtocol** to define details about response in case of
failure

 Download Manager
=================

**SDDownloadManager** is the main class that manage all download communications,
cache the downloaded resources locally (in NSCache, File System, depending of
given settings). It use AFHTTPRequestOperationManager of AFNetworking framework
(vers. 2.0).

#### Main features:

-   search resources from **bundle** before download (ex. in case you have a
    bundle seed)

-   can use **file system** to persist downloaded resources

-   can use **NSCache** to retrieve them faster

-   can use **HEAD request to check new updates** of a downloaded resource
    (compare modified date of server resource with your local one and if reveal
    an update it will download it)

-   can define the local path to persist resources

-   **check global size of many resources** to download in a batch operation

-   **download many resources** in a batch operation

-   [SDDownloadImageView](#SDDownloadImageView) to handle download images in
    easy way

-   .....

The main methods are:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- (void) getResourceAtUrl:(NSString* _Nonnull)urlString type:(DownloadOperationType)type options:(SDDownloadOptions* _Nullable)options completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

and

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- (void) getResourceWithRequest:(NSMutableURLRequest* _Nonnull)request type:(DownloadOperationType)type options:(SDDownloadOptions* _Nullable)options completionSuccess:(SDDownloadManagerCompletionSuccessHandler _Nullable)completionSuccess progress:(SDDownloadManagerProgressHandler _Nullable)progress completionFailure:(SDDownloadManagerCompletionFailureHandler _Nullable)completionFailure;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

that looks for a resource locally and if not available or not still valid it
will download it. Before all it looks in Memory Cache or File System (depending
your settings) using MD5 of his url as key. If there is a resource locally, it
checks the validity using the ExpirationDatePlist (depending
useExpirationDatePlist settings) and checks its expiration date. If resource is
still valid is returned immediately, otherwise it fires a **HEAD request**
(depending of useHeadRequestToCheckUpdates setting) to **compare the
Modified-Date**. If Modified-Date is the same, local resource is valid and
returned, otherwise it starts to download the update. Once the resource is
download it will update the expiration date inside the ExpirationDatePlist (if
used), saved inside NSCache (if set) and into File System (if set). You can use
the second signature with NSMutableRequest if the web server requires more
specific parameters before providing resources (ex. header custom, HTTP post
method, ...).

SDDownloadManager can be also used to **count in batch the total size of
resources** at given urls.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- (void) countDownloadSizeForResourceAtUrls:(NSArray<NSString*>* _Nonnull)urlStrings options:(SDDownloadOptions* _Nullable)options progress:(SDDownloadManagerBatchOperationProgressHandler _Nullable)progress completion:(SDDownloadManagerCheckSizeCompletion _Nullable)completion
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

this method check all missing resources and count the amount of all
Content-Lenght. After this, if you want to **download all checked and missing
resources**, you can use

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- (void) downloadAllElementsCheckedWithProgress:(SDDownloadManagerBatchOperationProgressHandler _Nullable)progress completion:(SDDownloadManagerBatchOperationCompletion _Nullable)completion;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

###  Download Image View

If you don't need much control, but only to handle images from remote servers,
you can use SDDownloadImageView. It's a subclass of UIImageView that handle
download, persist, animation and many option about images stored in remote
servers. Internally this class use SDDownloadManager features to provide all
transparently for you.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
NSString* urlString = @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg";

SDDownloadImageView* downloadImageView = [SDDownloadImageView new];
downloadImageView.showActivityIndicatorWhileLoading = YES;
downloadImageView.showLocalImageBeforeCheckingValidity = YES;
downloadImageView.placeHolderImage = nil;
    
[downloadImageView setImageWithURLString:urlString completion:^(NSString* urlString, UIImage* image, DownloadOperationResultType resultType) {
    }];
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For more details and options see attached example and documentation in the .h
files.
