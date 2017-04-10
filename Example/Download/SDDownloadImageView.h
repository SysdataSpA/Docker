//
//  SDDownloadImageView.h
//  YooxNative
//
//  Created by Francesco Ceravolo on 30/06/14.
//  Copyright (c) 2014 Yoox Group. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "UIImageViewAligned.h"
#import "SDDownloadManager.h"

typedef void (^ SDDownloadImageViewCompletionHandler)(NSString* _Nullable urlString, UIImage* _Nullable image, DownloadOperationResultType resultType);


typedef NS_OPTIONS (NSUInteger, SDDownloadImageTransitionType)
{
    // transition effects
    SDDownloadImageTransitionNone                       = 0 << 20,                 // default
    SDDownloadImageTransitionCrossDissolve              = 1 << 20,
    
    SDDownloadImageTransitionScaleDissolve              = 2 << 20,
    SDDownloadImageTransitionPerspectiveDissolve        = 3 << 20,
    
    SDDownloadImageTransitionSlideInTop                 = 4 << 20,
    SDDownloadImageTransitionSlideInLeft                = 5 << 20,
    SDDownloadImageTransitionSlideInBottom              = 6 << 20,
    SDDownloadImageTransitionSlideInRight               = 7 << 20,
    
    SDDownloadImageTransitionFlipFromLeft               = 8 << 20,
    SDDownloadImageTransitionFlipFromRight              = 9 << 20,
    
    SDDownloadImageTransitionRipple                     = 10 << 20,
    SDDownloadImageTransitionCubeFromTop                = 11 << 20,
    SDDownloadImageTransitionCubeFromLeft               = 12 << 20,
    SDDownloadImageTransitionCubeFromBottom             = 13 << 20,
    SDDownloadImageTransitionCubeFromRight              = 14 << 20,
    
    SDDownloadImageTransitionCoolPulse                  = 15 << 20,
};



@interface SDDownloadImageView : UIImageViewAligned

/**
 *  Type of animation executed when the image will be updated. The animation will fired when:
 *  - image is downloaded new
 *  - local image is valid after checking for updates with head request, but image isn't shown yet (showLocalImageBeforeCheckingValidity = NO)
 
 *  Default = SDDownloadImageTransitionCrossDissolve
 */
@property (nonatomic, assign) SDDownloadImageTransitionType transitionType;

/**
 *  shows an activity indicator while image is loading
 *  Default = NO
 */
@property (nonatomic, assign) BOOL showActivityIndicatorWhileLoading;

/**
 *  Shows the local image also before checking updates with head request. If enabled the image will be updated next. If disabled the image shown will always be the final one.
 
 *  Default = YES;
 */
@property (nonatomic, assign) BOOL showLocalImageBeforeCheckingValidity;

/**
 *  performs the complition block only when the image changes
 *  Default = YES
 */
@property (nonatomic, assign) BOOL performCompletionOnlyAtImageChanges;


@property (nonatomic, strong, readonly) NSString* _Nullable urlString;

/**
 *  The placeholder image to shown while loading the desired one from ulr
 */
@property (nonatomic, strong) UIImage* _Nullable placeHolderImage;

/**
 *  The image to show if there is a failure while retreiving the desired
 */
@property (nonatomic, strong) UIImage* _Nullable downloadFailureImage;

/**
 *  Options to set while retreiving the image
 */
@property (nonatomic, strong) SDDownloadOptions* _Nullable downloadOptions;


/**
 *  Start retreiving the image (form local or downloading from remote) usign the SDDwonloadManager. Updates and image managements are completely auotnomous and handled by the SDDownloadManager. In case should be usefull get infos about the retreived image use the completion handler.
 *
 *  @param urlString          url of the desired resource (use this or specific request)
 *  @param request            request to download the resource (use this only for specific case that needs custom HTTP request with headers, methods, parameters, ...)
 *  @param completion         block executed when the image is returned
 */
- (void) setImageWithURLString:(NSString* _Nonnull)urlString completion:(SDDownloadImageViewCompletionHandler _Nullable)completion;
- (void) setImageWithURLWithRequest:(NSMutableURLRequest* _Nonnull)request completion:(SDDownloadImageViewCompletionHandler _Nullable)completion;
- (void) setImageWithURLString:(NSString* _Nonnull)urlString;

@end
