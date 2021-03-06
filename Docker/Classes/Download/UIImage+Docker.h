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

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, UIImageResizeFillType) {
    UIImageResizeFillTypeIgnoreAspectRatio = 0,
    UIImageResizeFillTypeFillIn = 1,
    UIImageResizeFillTypeFitIn = 2,
};

@interface UIImage (Docker)

/*
 * resize image with options to keep aspect ratio using different method. And optionally round the corners
 */
- (UIImage*) sd_resize : (CGSize)newSize
              fillType : (UIImageResizeFillType) fillType
         topLeftCorner : (CGFloat)topLeftCorner
        topRightCorner : (CGFloat)topRightCorner
     bottomRightCorner : (CGFloat)bottomRightCorner
      bottomLeftCorner : (CGFloat)bottomLeftCorner quality:(CGInterpolationQuality)quality;

// resize and not keep the aspect ratio
- (UIImage*) sd_resize : (CGSize)newSize roundCorner:(CGFloat)roundCorner quality:(CGInterpolationQuality)quality;
// resize and keep the aspect ratio using fill in
- (UIImage*) sd_resizeFillIn : (CGSize)newSize roundCorner:(CGFloat)roundCorner quality:(CGInterpolationQuality)quality;
// resize and keep the aspect ratio using fit in, not draw area will be in transparent color
- (UIImage*) sd_resizeFitIn : (CGSize)newSize roundCorner:(CGFloat)roundCorner quality:(CGInterpolationQuality)quality;

// crop image, handled scale and orientation
- (UIImage*) sd_crop : (CGRect) cropRect;

// return an image that orientation always UIImageOrientationUp
- (UIImage*) sd_normalizeOrientation;

#pragma mark - above didn't add prefix for historic reason, functions below added prefix

// normalize will convert image to jpeg and that load it back. It will normalize everything including colorspace and orientation
- (UIImage*) sd_normalize;

// generate plain image from color
+ (UIImage*) sd_imageWithUIColor : (UIColor*) color size : (CGSize) size;
// create a radial graident mask
+ (UIImage*) sd_spotMask:(CGSize)size center:(CGPoint)center startRadius:(CGFloat)startRadius endRadius:(CGFloat)endRadius inverted:(BOOL)inverted;

// apply gradient shading on top of the image, grayscale only
- (UIImage*) sd_imageWithLinearGradient:(CGFloat)direction intensity:(CGFloat)intensity;
// components is a CGFloat[4], [lum1, alpha1, lum2, alpha2]
- (UIImage*) sd_imageWithLinearGradient:(CGFloat)direction components:(CGFloat*)components;

// return image mask with another image, useful for e.g. tab icons
- (UIImage*) sd_imageWithMask:(UIImage*)maskImage;
// generic function to overlap two images
- (UIImage*) sd_imageWithOverlay:(UIImage*)topImage blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha scale:(BOOL)scale;

@end
