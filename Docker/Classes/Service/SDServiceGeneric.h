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
#import <AFNetworking/AFNetworking.h>

/**
 *  HTTP methots supported by SDServiceManager.
 */
typedef NS_ENUM (NSUInteger, SDHTTPMethod)
{
    /**
     *  HTTP GET.
     */
    SDHTTPMethodGET = 0,
    /**
     *  HTTP POST.
     */
    SDHTTPMethodPOST,
    /**
     *  HTTP PUT.
     */
    SDHTTPMethodPUT,
    /**
     *  HTTP DELETE.
     */
    SDHTTPMethodDELETE,
    /**
     *  HTTP HEAD.
     */
    SDHTTPMethodHEAD,
    /**
     *  HTTP PATCH.
     */
    SDHTTPMethodPATCH
};

@interface MultipartBodyInfo : NSObject

@property (nonatomic, strong) NSData* _Nullable data;
@property (nonatomic, strong) NSString* _Nullable name;
@property (nonatomic, strong) NSString* _Nullable fileName;
@property (nonatomic, strong) NSString* _Nullable mimeType;

@end


/**
 *  Protocol implemented by all requests.
 */
@protocol SDServiceGenericRequestProtocol <NSObject>
@optional
/**
 *  Headers to modify or add to the defaults.
 */
@property (nonatomic, strong) NSDictionary* _Nullable additionalRequestHeaders;
/**
 *  Parameters to send in addition of parameters defined in the request object.
 */
@property (nonatomic, strong) NSDictionary* _Nullable additionalRequestParameters;

/**
 *  Enable to remove parameters without value from request (otherwise parameters will be passed with 'null' value)
 */
@property (nonatomic, assign) BOOL removeNilParameters;


/**
 *  Infos about NSData to send in multipart calls
 */
@property (nonatomic, strong) NSArray<MultipartBodyInfo*>* _Nullable multipartInfos;

@end






/**
 *  Protocol implemented by all responses.
 */
@protocol SDServiceGenericResponseProtocol <NSObject>
@required
/**
 *  HTTP status code returned by service.
 */
@property (nonatomic, assign) int httpStatusCode;

/**
 *  Headers of the reponse
 */
@property (nonatomic, strong) NSDictionary* _Nullable headers;

/**
 *  Property name mapped in case service starts with an array object instead of dictionary object.
 */
@property (readonly, nonatomic, strong) NSString* _Nullable propertyNameForArrayResponse;

/**
 *  Class of objects inside body response in case service starts with an array object instead of dictionary object.
 */
@property (readonly, nonatomic, assign) Class _Nullable classOfItemsInArrayResponse;
@end




/**
 *  Protocol implemented by all errors.
 */
@protocol SDServiceGenericErrorProtocol <NSObject>
@required
/**
 *  HTTP status code returned by service.
 */
@property (nonatomic, assign) int httpStatusCode;
/**
 *  Error object returned by SDServiceManager in case of service failure.
 */
@property (nonatomic, strong) NSError* _Nullable error;
@end





/**
 *  Protocol implemented by all services (SDServiceGeneric).
 */
@protocol SDServiceGenericProtocol <NSObject>
@required
/**
 *  Service path that will be added at SDServiceManager base url.
 *
 *  @return service path relative to base url.
 */
- (NSString* _Nonnull) pathResource;

/**
 *  Operation manager to use for the service. By default will be used the operation manager instanciated by SDServiceManager.
 
 *  @discussion tipically don't override it to use the default one. Return specific instance of AFHTTPRequestOperationManager to manage services in differents queue.
 *
 *  @return operation manager to use for the service.
 */
- (AFHTTPRequestOperationManager* _Nonnull) requestOperationManager;

/**
 *  HTTP method to use in the service call. Look at SDHTTPMethod for details. By default return SDHTTPMethodGET.
 *
 *  @return HTTP method.
 */
- (SDHTTPMethod) requestMethodType;

/**
 *  Return dictionary that rapresents parameters used in query string or in body of request (depending by the HTTP method). Use this method to parse your object. If your service is application/json you can use SDServiceMantle.
 *
 *  @param request    request.
 *  @param error      possible error mapping (passed by reference).
 *
 *  @return dictionary of parameters. In case of failure, error object will be instantiate.
 */
- (NSDictionary* _Nullable) parametersForRequest:(id<SDServiceGenericRequestProtocol> _Nullable)request error:(NSError*_Nullable* _Nullable)error;

/**
 *  Return the service response starting from the response object (NSDictionary or NSArray).
 Restituisce la response del servizio a partire dal NSDictionary di risposta o nil se l'oggetto del servizio non può essere mappato.
 *
 *  @param object     object returned by service that will be mapped in the final response object.
 *  @param error      possible error mapping (passed by reference).
 *
 *  @return final response object or nil in case of failure. In case of failure, error object will be instantiate.
 */
- (id<SDServiceGenericResponseProtocol>_Nullable) responseForObject:(id _Nullable)object error:(NSError*_Nullable* _Nullable)error;

/**
 *  Return the error response starting from the response object (NSDictionary).
 *
 *  @param object     object returned by service that will be mapped in the final error object.
 *  @param error      possible error mapping (passed by reference).
 *
 *  @return final error object or nil in case of failure. In case of failure, error object will be instantiate.
 */
- (id<SDServiceGenericErrorProtocol> _Nullable) errorForObject:(id _Nullable)object error:(NSError*_Nullable* _Nullable)error;

/**
 *  Object class for the service response.
 *
 *  @return class of response.
 */
- (Class _Nullable) responseClass;

/**
 *  Error class for the service response in case of failure.
 *
 *  @return class of error.
 */
- (Class _Nullable) errorClass;

@optional
/**
 *  Falg to anable service to retreive the response from a local file (set in demoModeJsonFileName)
 *
 *  @return YES if should retreive response from local file. NO if server should call the server. Default is NO.
 */
- (BOOL) useDemoMode;

/**
 *  File name of local file that contains the response of service (in the Bundle).
 *
 *  @return local file name.
 */
- (NSString* _Nullable) demoModeJsonFileName;

/**
 *  Range for get a random value inside that will be used as waiting time for the service called in dem mode.
 *
 *  @return range for the waiting time
 */
- (NSRange) demoWaitingTimeRange;


/**
 *  File name of local file that contains the response of service (in the Bundle) to simulate error cases.
 *
 *  @return local file name.
 */
- (NSString* _Nullable) demoModeJsonFailureFileName;


/**
 *  Status code to return in case of failure in demo mode.
 *
 *  @return status code in failure case.
 */
- (int) demoModeFailureStatusCode;


/**
 *  Probability of error in demo mode. Default is 0 (never appens). This value must be between 0 and 1 (0 = never appens, 1 = always appens)
 *
 *  @return chance of error occurs.
 */
- (double) demoModeFailureChanceEvent;


@end





/**
 *  Base class to subclass defining custom services. This base implementation doesn't provide any mapping for request and response. Tipically subclass to define the SDServiceGenericProtocol methods. If your service is an application/json subcalss SDServiceMantle and use Mantle to parse json objects.
 */
@interface SDServiceGeneric : NSObject <SDServiceGenericProtocol>
/**
 *  Flag to repeat service in case of failure.
 */
@property (nonatomic, readonly) BOOL isRepeatable;
/**
 *  Retreive response from a local file. The default name of file is the Class name of service, but it can be override using method -(NSString*)demoModeJsonFileName.
 *
 *  @return La response recuperata da file locale o nil se non riesce a recuperarla.
 */
- (void) getResultFromJSONFileWithCompletion:(void (^_Nullable)  (id _Nullable result))completion;
- (void) getResultFromJSONFileAtPath:(NSString* _Nonnull)pathToFile withCompletion:(void (^_Nullable) (id _Nullable result))completion;

@end
