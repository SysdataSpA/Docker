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

#import "SDDownloadImageView.h"
#import "UIImage+Docker.h"
#import "SDDockerLogger.h"

#define kAIVTag                     8000
#define DIV_BASE_ANIMATION_DURATION 0.3

@interface SDDownloadImageView ()
{
    UIActivityIndicatorView* aiv;
    
    float transitionDuration;
    
    BOOL observerAdded;
}

@property (nonatomic, strong, readwrite) NSString* urlString;
@property (nonatomic, strong) SDDownloadImageViewCompletionHandler completionHandler;

@end

@implementation SDDownloadImageView

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self setup];
    }
    return self;
}

- (void) setup
{
    transitionDuration = DIV_BASE_ANIMATION_DURATION;
    
    self.showActivityIndicatorWhileLoading = NO;
    self.transitionType = SDDownloadImageTransitionCrossDissolve;
    self.showLocalImageBeforeCheckingValidity = YES;
    self.performCompletionOnlyAtImageChanges = YES;
}

- (void) setShowActivityIndicatorWhileLoading:(BOOL)showActivityIndicatorWhileLoading
{
    _showActivityIndicatorWhileLoading = showActivityIndicatorWhileLoading;
    
    if (showActivityIndicatorWhileLoading)
    {
        aiv = (UIActivityIndicatorView*)[self viewWithTag:kAIVTag];
        if (!aiv)
        {
            aiv = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            aiv.tag = kAIVTag;
            aiv.hidesWhenStopped = YES;
            aiv.center = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
            aiv.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
            [self addSubview:aiv];
        }
    }
}

- (void)setPlaceHolderImage:(UIImage *)placeHolderImage
{
    _placeHolderImage = placeHolderImage;
    self.image = placeHolderImage;
}


- (void) dealloc
{
    self.completionHandler = nil;
    self.urlString = nil;
    self.image = nil;
}

- (void) setImageWithURLString:(NSString*)urlString
{
    [self setImageWithURLString:urlString completion:nil];
}
- (void) setImageWithURLString:(NSString*)urlString completion:(SDDownloadImageViewCompletionHandler)completion
{
    [self setImageWithURLWithRequest:nil urlString:urlString completion:completion];
}
- (void) setImageWithURLWithRequest:(NSMutableURLRequest*)request completion:(SDDownloadImageViewCompletionHandler)completion
{
    [self setImageWithURLWithRequest:request urlString:nil completion:completion];
}


- (void) setImageWithURLWithRequest:(NSMutableURLRequest*)request urlString:(NSString*)urlString completion:(SDDownloadImageViewCompletionHandler)completion
{
    self.completionHandler = completion;
    
    self.image = self.placeHolderImage;
    
    if (self.showActivityIndicatorWhileLoading)
    {
        [self bringSubviewToFront:aiv];
        [aiv startAnimating];
    }
    else
    {
        [aiv stopAnimating];
    }
    
    
    if (urlString || request)
    {
        self.urlString = urlString ? urlString : request.URL.absoluteString;
        
        __weak typeof (self) weakSelf = self;
        SDDownloadManagerCompletionSuccessHandler successCompletionBlock = ^(id downloadedObject, NSString *urlString, NSString *localPath, DownloadOperationResultType resultType) {
            if([weakSelf.urlString isEqualToString:urlString])
            {
                [weakSelf updateImage:(UIImage*)downloadedObject forResultType:resultType];
            }
            else
            {
                NSLog(@"errorrr");
            }
        };
        
        SDDownloadManagerCompletionFailureHandler failureCompletionBlock = ^(NSString * _Nullable urlString, NSError * _Nullable error) {
            if([weakSelf.urlString isEqualToString:urlString])
            {
                if(weakSelf.downloadFailureImage)
                {
                    weakSelf.image = weakSelf.downloadFailureImage;
                }
            }
            else
            {
                NSLog(@"errorrr");
            }
        };
        
        if (request)
        {
            [[SDDownloadManager sharedManager] getResourceWithRequest:request type:DownloadOperationTypeImage options:self.downloadOptions completionSuccess:successCompletionBlock progress:nil completionFailure:failureCompletionBlock];
        }
        else
        {
            [[SDDownloadManager sharedManager] getResourceAtUrl:self.urlString type:DownloadOperationTypeImage options:self.downloadOptions completionSuccess:successCompletionBlock progress:nil completionFailure:failureCompletionBlock];
        }
    }
}

- (void) updateImage:(UIImage*)image forResultType:(DownloadOperationResultType)resultType
{
    BOOL performCompletion = YES;
    
    if (image)
    {
        if (resultType == DownloadOperationResultLoadLocallyCheckingValid && !self.showLocalImageBeforeCheckingValidity)
        {
            // don't show image immediatly if not sure it will be the final one
            SDLogModuleVerbose(kDownloadManagerLogModuleName, @"SDDownloadImageView: wait checking local image validity");
            performCompletion = NO;
        }
        else
        {
            if (self.showActivityIndicatorWhileLoading)
            {
                [aiv stopAnimating];
            }
            
            if (resultType == DownloadOperationResultDownloadedNew  || (resultType == DownloadOperationResultLoadLocallyCheckingValidSuccessed && !self.showLocalImageBeforeCheckingValidity))
            {
                // perform animation if image is downloaded new or confirmed that local one is still valid and it isn't shown yet
                [self makeTransition:image effect:self.transitionType];
            }
            else
            {
                self.image = image;
            }
        }
        
        if (resultType == DownloadOperationResultLoadLocallyCheckingValidSuccessed && self.showLocalImageBeforeCheckingValidity)
        {
            performCompletion = NO;
        }
        
        if (!self.performCompletionOnlyAtImageChanges || performCompletion)
        {
            if (self.completionHandler)
            {
                self.completionHandler(self.urlString, image, resultType);
            }
        }
    }
    else
    {
        SDLogModuleWarning(kDownloadManagerLogModuleName, @"SDDownloadImageView: image not found");
        if(self.downloadFailureImage)
        {
            self.image = self.downloadFailureImage;
        }
    }
}



#pragma mark Transitions Effect

- (CALayer*) layerFromImage:(UIImage*)image
{
    CALayer* layer = [CALayer layer];
    
    layer.contents = (__bridge id)([image sd_normalizeOrientation].CGImage);
    layer.frame = self.bounds;
    return layer;
}

- (void) makeTransition:(UIImage*)image effect:(SDDownloadImageTransitionType)effect
{
    switch (effect)
    {
            // OS-provided CALayer CATranstion type transition animation
        case SDDownloadImageTransitionCrossDissolve :
        case SDDownloadImageTransitionRipple :
        case SDDownloadImageTransitionCubeFromRight :
        case SDDownloadImageTransitionCubeFromLeft :
        case SDDownloadImageTransitionCubeFromTop :
        case SDDownloadImageTransitionCubeFromBottom :
        {
            CATransition* animation = [CATransition animation];
            [animation setDuration:transitionDuration];
            // [animation setSubtype:kCATransitionFromLeft];
            // rippleEffect, cube, oglFlip...
            switch (effect)
            {
                default :
                    [animation setType:kCATransitionFade]; break;
                    
                case SDDownloadImageTransitionCubeFromTop :
                    [animation setType:@"cube"]; [animation setSubtype:kCATransitionFromTop]; break;
                    
                case SDDownloadImageTransitionCubeFromBottom :
                    [animation setType:@"cube"]; [animation setSubtype:kCATransitionFromBottom]; break;
                    
                case SDDownloadImageTransitionCubeFromLeft :
                    [animation setType:@"cube"]; [animation setSubtype:kCATransitionFromLeft]; break;
                    
                case SDDownloadImageTransitionCubeFromRight :
                    [animation setType:@"cube"]; [animation setSubtype:kCATransitionFromRight]; break;
                    
                case SDDownloadImageTransitionRipple :
                    [animation setType:@"rippleEffect"]; break;
            }
            [self.layer addAnimation:animation forKey:@"transition"];
            self.image = image;
        } break;
            
            // Custom dissolve type animation
        case SDDownloadImageTransitionScaleDissolve :
        case SDDownloadImageTransitionPerspectiveDissolve :
        {
            CALayer* layer = [self layerFromImage:image];
            switch (effect)
            {
                default :
                    
                case SDDownloadImageTransitionScaleDissolve :
                    layer.affineTransform = CGAffineTransformMakeScale(1.5, 1.5); break;
                    
                case SDDownloadImageTransitionPerspectiveDissolve :
                {
                    CATransform3D t = CATransform3DIdentity;
                    t.m34 = 1.0 / -450.0;
                    t = CATransform3DScale(t, 1.2, 1.2, 1);
                    t = CATransform3DRotate(t, 45.0f * M_PI / 180.0f, 1, 0, 0);
                    t = CATransform3DTranslate(t, 0, self.bounds.size.height * 0.1, 0);
                    layer.transform = t;
                } break;
            }
            layer.opacity = 0.0f;
            [self.layer addSublayer:layer];
            [CATransaction flush];
            [CATransaction begin];
            [CATransaction setAnimationDuration:transitionDuration];
            __weak typeof (self) weakSelf = self;
            [CATransaction setCompletionBlock: ^{
                [layer removeFromSuperlayer];
                weakSelf.image = image;
            }];
            layer.opacity = 1.0f;
            layer.affineTransform = CGAffineTransformIdentity;
            [CATransaction commit];
        } break;
            
            // Custom slide type animation
        case SDDownloadImageTransitionSlideInTop :
        case SDDownloadImageTransitionSlideInLeft :
        case SDDownloadImageTransitionSlideInBottom :
        case SDDownloadImageTransitionSlideInRight :
        {
            CALayer* layer = [self layerFromImage:image];
            BOOL clipsToBoundsSave = self.clipsToBounds;
            self.clipsToBounds = YES;
            switch (effect)
            {
                default :
                case SDDownloadImageTransitionSlideInTop :
                    layer.affineTransform = CGAffineTransformMakeTranslation(0, -self.bounds.size.height); break;
                    
                case SDDownloadImageTransitionSlideInLeft :
                    layer.affineTransform = CGAffineTransformMakeTranslation(-self.bounds.size.width, 0); break;
                    
                case SDDownloadImageTransitionSlideInBottom :
                    layer.affineTransform = CGAffineTransformMakeTranslation(0, self.bounds.size.height); break;
                    
                case SDDownloadImageTransitionSlideInRight :
                    layer.affineTransform = CGAffineTransformMakeTranslation(self.bounds.size.width, 0); break;
                    break;
            }
            [self.layer addSublayer:layer];
            [CATransaction flush];
            [CATransaction begin];
            [CATransaction setAnimationDuration:transitionDuration];
            __weak typeof (self) weakSelf = self;
            [CATransaction setCompletionBlock: ^{
                [layer removeFromSuperlayer];
                weakSelf.image = image;
                // have sublayer means animation in progress
                NSArray* sublayer = weakSelf.layer.sublayers;
                if (sublayer.count == 1)
                {
                    weakSelf.clipsToBounds = clipsToBoundsSave;
                }
            }];
            layer.affineTransform = CGAffineTransformIdentity;
            [CATransaction commit];
        } break;
            
            // OS-provided UIView type transition animation
        case SDDownloadImageTransitionFlipFromLeft :
        case SDDownloadImageTransitionFlipFromRight :
        {
            [UIView beginAnimations:nil context:nil];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            [UIView setAnimationBeginsFromCurrentState:YES];
            [UIView setAnimationDuration:transitionDuration];
            switch (effect)
            {
                case SDDownloadImageTransitionFlipFromLeft :
                    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self cache:YES]; break;
                    
                case SDDownloadImageTransitionFlipFromRight :
                    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self cache:YES]; break;
                    
                default :
                    break;
            }
            self.image = image;
            [UIView commitAnimations];
            break;
        } break;
            
        case SDDownloadImageTransitionCoolPulse :
        {
            self.transform = CGAffineTransformMakeScale(0.1, 0.1);
            __weak typeof (self) weakSelf = self;
            [UIView animateWithDuration:DIV_BASE_ANIMATION_DURATION * 2 delay:0. usingSpringWithDamping:.4 initialSpringVelocity:0. options:0 animations:^{
                weakSelf.transform = CGAffineTransformMakeScale(1, 1);
            } completion:nil];
            
            self.image = image;
            
            break;
        } break;
            
        default :
            self.image = image;
            break;
    }
}

@end
