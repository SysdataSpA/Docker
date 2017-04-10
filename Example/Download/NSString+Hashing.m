//
//  NSString+MD5Addition.m
//  UIDeviceAddition
//
//  Created by Georg Kitz on 20.08.11.
//  Copyright 2011 Aurora Apps. All rights reserved.
//

#import "NSString+Hashing.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation NSString (Hashing)

- (NSString *)MD5String {
	if (self == nil || [self length] == 0)
		return nil;

	const char *value = [self UTF8String];

	unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
	CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);

	NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
	for (NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++) {
		[outputString appendFormat:@"%02x", outputBuffer[count]];
	}

	return outputString;
}

- (NSString *)SHA512StringWithSalt:(NSString *)salt {
	const char *cKey  = [salt cStringUsingEncoding:NSUTF8StringEncoding];
	const char *cData = [self cStringUsingEncoding:NSUTF8StringEncoding];
	unsigned char cHMAC[CC_SHA512_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA512, cKey, strlen(cKey), cData, strlen(cData), cHMAC);

	NSString *hash;

	NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA512_DIGEST_LENGTH * 2];

	for (int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++)
		[output appendFormat:@"%02x", cHMAC[i]];
	hash = output;
	return hash;
}

- (NSString *)SHA256String {
	NSData *cData = [self dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char hash[CC_SHA256_DIGEST_LENGTH];
	if (CC_SHA256([cData bytes], (CC_LONG)[cData length], hash)) {
		NSString *hashedString;
		NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH];
		for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
			[output appendFormat:@"%02x", hash[i]];
		hashedString = output;
		return hashedString;
	}
	return nil;
}

@end
