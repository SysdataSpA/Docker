//
//  SDFileManager.m
//  YooxTheCorner
//
//  Created by cecco on 26/09/13.
//
//

#import "SDFileManager.h"
#import "SDDownload.h"


@implementation SDFileInfo


@end




@implementation SDFileManager

+ (instancetype)sharedManager
{
    static dispatch_once_t pred;
    static id fileManagerInstance_ = nil;
    
    dispatch_once(&pred, ^{
        fileManagerInstance_ = [[self alloc] init];
    });
    
    return fileManagerInstance_;
}

- (NSString*) documentsDirectory
{
    NSString* result = _documentsDirectory;
    if(!result)
    {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        result = [paths objectAtIndex:0]; // Get documents folder
        _documentsDirectory = result;
    }
    
    return result;
}

- (NSString*) cacheDirectory
{
    NSString* result = _cacheDirectory;
    if(!result)
    {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        result = [paths objectAtIndex:0]; // Get documents folder
        _cacheDirectory = result;
    }
    
    return result;
}

- (NSString*) applicationSupportDirectory
{
    NSString* result = _applicationSupportDirectory;
    if(!result)
    {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        result = [paths objectAtIndex:0]; // Get documents folder
        _applicationSupportDirectory = result;
    }
    
    return result;
}

#pragma mark File Utilities

+ (NSString*) getFileNameFromUrl:(NSString*)url
{
	return [url stringByReplacingOccurrencesOfString:@"/" withString:@""];
}

+ (NSString*) getPathOfResourceDirectory
{
    NSString* cacheDirectory = [SDFileManager sharedManager].cacheDirectory;
    return [cacheDirectory stringByAppendingPathComponent:RESOURCES_DIRECTORY];
}

+ (BOOL) deleteResourceDirectory
{
    NSFileManager* fm = [NSFileManager defaultManager];

    NSString* resourceCache = [SDFileManager getPathOfResourceDirectory];
    NSError* error = nil;
    if(![fm removeItemAtPath:resourceCache error:&error])
    {
        SDLogError(@"Rimozione resource directory fallita: %@ \nErrore: %@\n%@", resourceCache, error, [error userInfo]);
        return NO;
    }
    return YES;
}

+ (void) createDirectoryForFileAtPathIfNeeded:(NSString*)filePath
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSError* error = nil;

	if (![fm createDirectoryAtPath:[filePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error])
	{
		SDLogError(@"Creazione directory fallita: %@ \nErrore: %@\n%@", [filePath stringByDeletingLastPathComponent], error, [error userInfo]);
	}
}

+ (BOOL) createDirectoryAtPath:(NSString*)folderPath withIntermediateDirectories:(BOOL)createIntemediate
{
	// if not exist, it will be created
	NSError* error;

	if (![[NSFileManager defaultManager] fileExistsAtPath:folderPath])
	{
		if (![[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:createIntemediate attributes:nil error:&error])
		{
			SDLogError(@"Create directory error: %@", error);
            return NO;
		}
	}

	return YES;
}

+ (NSArray*) getFilesContentInDirectoryNamed:(NSString*)directoryName
{
	NSError* error;
	NSArray* dirContents;

	if ([[NSFileManager defaultManager] fileExistsAtPath:directoryName])
	{
		dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryName error:&error];
		if (error)
		{
			SDLogError(@"Error get files in directory: %@", error);
		}
	}

	return dirContents;
}

+ (NSArray*) getInfoAboutFilesContentInDirectoryNamed:(NSString*)directoryName
{
	NSArray* dirContents = [SDFileManager getFilesContentInDirectoryNamed:directoryName];
	NSMutableArray* arrayFileInfo = [[NSMutableArray alloc] initWithCapacity:0];

	for (NSString* fileName in dirContents)
	{
		NSString* filePath = [directoryName stringByAppendingPathComponent:fileName];

		SDFileInfo * fileInfo = [SDFileManager getInfoAboutFileAtPath:filePath];
        
        if (fileInfo)
            [arrayFileInfo addObject:fileInfo];
	}

	return arrayFileInfo;
}



+ (SDFileInfo*) getInfoAboutFileAtPath:(NSString*)path
{
	NSError* error = nil;
	NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];

	if (error != nil || attrs == nil)
	{
		SDLogError(@"Can't get file info");
		return nil;
	}
	else
	{
		NSDate* creationDate = (NSDate*)[attrs objectForKey:NSFileCreationDate];
		NSDate* modificationDate = (NSDate*)[attrs objectForKey:NSFileModificationDate];

		SDFileInfo* fileInfo = [[SDFileInfo alloc] init];
		fileInfo.name = [path lastPathComponent];
		fileInfo.modificationDateOnServer = creationDate;
		fileInfo.downloadDateLocal = modificationDate;
		fileInfo.path = path;

		return fileInfo;
	}
}

+ (SDFileInfo*) getInfoAboutFileNamed:(NSString*)fileName inDirectoryNamed:(NSString*)directoryName
{
	fileName = [SDFileManager getFileNameFromUrl:fileName];

	NSString* filePath = [directoryName stringByAppendingPathComponent:fileName];
	return [SDFileManager getInfoAboutFileAtPath:filePath];
}


+ (BOOL) deleteFilesContentInDirectoryNamed:(NSString*)directoryName withModifyDateBefore:(NSDate*)expirationDate
{
	
	NSArray* dirContents = [SDFileManager getFilesContentInDirectoryNamed:directoryName];
	
	for (NSString* fileName in dirContents)
	{
		NSString* filePath = [directoryName stringByAppendingPathComponent:fileName];
        
		SDFileInfo * fileInfo = [SDFileManager getInfoAboutFileAtPath:filePath];
        
        if([fileInfo.downloadDateLocal compare:expirationDate] == NSOrderedAscending)
           [SDFileManager deleteFilesAtPath:filePath];
	}
    
	return YES;
}


+ (BOOL) deleteFilesAtPath:(NSString*)filePath
{
	NSError* error;
	BOOL success = NO;

	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
	{
		success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
		if (error)
		{
			SDLogError(@"Error remove files at path: %@. Error: %@", filePath, error.localizedDescription);
		}
	}

	return success;
}

#pragma mark - Images
+ (UIImage*) getImageNamed:(NSString*)fileName inDirectoryNamed:(NSString*)directoryName
{
	fileName = [SDFileManager getFileNameFromUrl:fileName];

	NSString* filePath = [directoryName stringByAppendingPathComponent:fileName];

	return [UIImage imageWithContentsOfFile:filePath];
}

+ (void) saveImage:(UIImage*)image named:(NSString*)fileName inDirectoryNamed:(NSString*)directoryName
{
	fileName = [SDFileManager getFileNameFromUrl:fileName];

	NSString* filePath = [directoryName stringByAppendingPathComponent:fileName];

	NSData* pngData = UIImagePNGRepresentation(image);
	[pngData writeToFile:filePath atomically:YES];
}

@end
