//
//  SDFileManager.h
//  YooxTheCorner
//
//  Created by cecco on 26/09/13.
//
//

#import <Foundation/Foundation.h>

#define RESOURCES_DIRECTORY @"resources"

@interface SDFileInfo : NSObject

@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSDate* modificationDateOnServer;
@property (nonatomic, strong) NSDate* downloadDateLocal;
@property (nonatomic, strong) NSString* path;

@end


@interface SDFileManager : NSObject

@property (nonatomic, strong) NSString* cacheDirectory;
@property (nonatomic, strong) NSString* documentsDirectory;
@property (nonatomic, strong) NSString* applicationSupportDirectory;

+ (instancetype) sharedManager;

+ (NSString*) getFileNameFromUrl:(NSString*)url;

// File Utilities
+ (NSString*) getPathOfResourceDirectory;
+ (BOOL) deleteResourceDirectory;

+ (void) createDirectoryForFileAtPathIfNeeded:(NSString*)filePath;
+ (BOOL) createDirectoryAtPath:(NSString*)folderPath withIntermediateDirectories:(BOOL)createIntemediate;

+ (NSArray*) getFilesContentInDirectoryNamed:(NSString*)directoryName;

+ (NSArray*) getInfoAboutFilesContentInDirectoryNamed:(NSString*)directoryName;
+ (SDFileInfo*) getInfoAboutFileAtPath:(NSString*)path;
+ (SDFileInfo*) getInfoAboutFileNamed:(NSString*)fileName inDirectoryNamed:(NSString*)directoryName;

+ (BOOL) deleteFilesAtPath:(NSString*)filePath;
+ (BOOL) deleteFilesContentInDirectoryNamed:(NSString*)directoryName withModifyDateBefore:(NSDate*)expirationDate;

// Images
+ (UIImage*) getImageNamed:(NSString*)fileName inDirectoryNamed:(NSString*)directoryName;
+ (void) saveImage:(UIImage*)image named:(NSString*)fileName inDirectoryNamed:(NSString*)directoryName;

@end
