#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

//#import "DKRFileManager.h"
//#import "NSObject+DownloadManager.h"
//#import "NSString+Docker.h"
//#import "SDDownloadImageView.h"
//#import "SDDownloadManager.h"
//#import "SDDownloadManagerUtils.h"
//#import "SDUIImageViewAligned.h"
//#import "UIImage+Docker.h"
#import "SDDocker.h"
#import "SDDockerLogger.h"
#import "NSDictionary+Docker.h"
#import "SDServiceGeneric.h"
#import "SDServiceManager.h"
#import "SDServiceMantle.h"
#import "SOCKit.h"

FOUNDATION_EXPORT double DockerVersionNumber;
FOUNDATION_EXPORT const unsigned char DockerVersionString[];

