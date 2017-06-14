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

#import "NSString+Hashing.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation NSString (DockerHashing)

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
