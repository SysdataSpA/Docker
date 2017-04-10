

#import <UIKit/UIKit.h>

// This code is compatible with our logger "Plinio".
#define kUmarellLogModuleName @"SysdataCore.DownloadManager"
#define kUmarellLogModuleColor @"fbeed7"
#ifdef SD_LOGGER_AVAILABLE
#import "SDLogger.h"
#else
#define SDLogError(frmt, ...)   NSLog(frmt, ##__VA_ARGS__)
#define SDLogWarning(frmt, ...) NSLog(frmt, ##__VA_ARGS__)
#define SDLogInfo(frmt, ...)    NSLog(frmt, ##__VA_ARGS__)
#define SDLogVerbose(frmt, ...) NSLog(frmt, ##__VA_ARGS__)
#define SDLogModuleError(mdl, frmt, ...)   NSLog(frmt, ##__VA_ARGS__)
#define SDLogModuleWarning(mdl, frmt, ...) NSLog(frmt, ##__VA_ARGS__)
#define SDLogModuleInfo(mdl, frmt, ...)    NSLog(frmt, ##__VA_ARGS__)
#define SDLogModuleVerbose(mdl, frmt, ...) NSLog(frmt, ##__VA_ARGS__)
#endif

#import "SDDownloadManager.h"
#import "SDDownloadImageView.h"


