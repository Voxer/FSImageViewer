//  FSImageViewer
//
//  Created by Felix Schulze on 8/26/2013.
//  Copyright 2013 Felix Schulze. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
#import "FSImageView.h"
#import "FSPlaceholderImages.h"
#import "FSImageScrollView.h"
#import "FLAnimatedImageView.h"

#define ZOOM_VIEW_TAG 0x101
#define MB_FILE_SIZE 1024*1024

@interface RotateGesture : UIRotationGestureRecognizer {
}
@end

@implementation RotateGesture
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gesture {
    return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
    return YES;
}
@end

@interface FSImageView()

//@property (nonatomic, strong) UAProgressView *progressView;

@end

@implementation FSImageView {
    CGFloat beginRadians;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {

        self.backgroundColor = [UIColor whiteColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.opaque = YES;
        self.rotationEnabled = YES;

        FSImageScrollView *scrollView = [[FSImageScrollView alloc] initWithFrame:self.bounds];
        scrollView.backgroundColor = [UIColor whiteColor];
        scrollView.opaque = YES;
        scrollView.delegate = self;
        [self addSubview:scrollView];
        _scrollView = scrollView;

        FLAnimatedImageView *imageView = [[FLAnimatedImageView alloc] initWithFrame:self.bounds];
        imageView.opaque = YES;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.tag = ZOOM_VIEW_TAG;
        [_scrollView addSubview:imageView];
        _imageView = imageView;
        
//        self.progressView = [[UAProgressView alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.frame) / 2) - 22.0f, CGRectGetHeight(self.frame) / 2 - 22.0f, 44.0f, 44.0f)];
//
//        _progressView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
//        [self addSubview:_progressView];

//        RotateGesture *gesture = [[RotateGesture alloc] initWithTarget:self action:@selector(rotate:)];
//        [self addGestureRecognizer:gesture];
    }
    return self;
}

- (void)dealloc {
    if (_image) {
        [self.imageSource cancelRequestForImage: self.image];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (_scrollView.zoomScale == 1.0f) {
        [self layoutScrollViewAnimated:YES];
    }

}

- (void)setImage:(id <FSImage>)aImage {

    if (!aImage) {
        return;
    }
    if ([aImage isEqual:_image]) {
        return;
    }
    if (_image != nil) {
        [self.imageSource cancelRequestForImage: _image];
    }

    _image = aImage;

    if (_image.image) {
        _imageView.image = _image.image;
    }
    else
    {
        _imageView.image = [UIImage imageNamed: @"image_placeholder_white"];

        __weak FSImageView* weakSelf = self;
        [self.imageSource loadImage: _image
                           progress: ^(float progress) {/* [weakSelf.progressView setProgress: progress animated: YES];*/ }
                              image: ^(UIImage* image, FLAnimatedImage* animatedImage, NSError* error)
                              {
                                  __strong FSImageView* strongSelf = weakSelf;
                                  if (!error)
                                  {
                                      if (image)
                                          strongSelf.image.image = image;
                                      else
                                          strongSelf.image.animatedImage = animatedImage;
                                      [strongSelf setupImageViewWithImage: image ?: animatedImage];
                                  }
                                  else
                                  {
                                      [strongSelf handleFailedImage];
                                  }
                              }];
    }

    if (_image.image)
    {
//        _progressView.hidden = YES;
        _loading = NO;

        [[NSNotificationCenter defaultCenter] postNotificationName:kFSImageViewerDidFinishedLoadingNotificationKey object:@{
                @"image" : self.image,
                @"failed" : @NO
        }];

    } else
    {
        _loading = YES;
        self.scrollView.maximumZoomScale = self.scrollView.minimumZoomScale = 1.0f;
    }
    [self layoutScrollViewAnimated:NO];
}

- (void) setupImageViewWithImage: (id) anImage
{
    if (!anImage) {
        return;
    }

    _loading = NO;
    if ([anImage isKindOfClass: UIImage.class])
    {
        _imageView.image = anImage;
    }
    else
        _imageView.animatedImage = anImage;

    [self layoutScrollViewAnimated:NO];

    [self.layer addAnimation: [self fadeAnimation] forKey: @"opacity"];

    [[NSNotificationCenter defaultCenter] postNotificationName: kFSImageViewerDidFinishedLoadingNotificationKey
                                                        object: @{ @"image"  : self.image,
                                                                   @"failed" : @NO }];
}

- (void) prepareForReuse
{
    self.tag = -1;
}

- (void) changeBackgroundColor: (UIColor*) color
{
    self.backgroundColor            = color;
    self.imageView.backgroundColor  = color;
    self.scrollView.backgroundColor = color;
}

- (void)changeProgressViewColor:(UIColor *)color {
//    _progressView.tintColor = color;
}

- (void) handleFailedImage
{
    _imageView.image = FSImageViewerErrorPlaceholderImage;
    _image.failed = YES;
    [self layoutScrollViewAnimated:NO];
//    _progressView.hidden = YES;
    [NSNotificationCenter.defaultCenter postNotificationName: kFSImageViewerDidFinishedLoadingNotificationKey
                                                      object: @{ @"image"  : self.image,
                                                                 @"failed" : @YES }];
}

- (void)resetBackgroundColors {
    self.backgroundColor = [UIColor whiteColor];
    self.superview.backgroundColor = self.backgroundColor;
    self.superview.superview.backgroundColor = self.backgroundColor;
}


#pragma mark - Layout

- (void)rotateToOrientation:(UIInterfaceOrientation)orientation {

    if (self.scrollView.zoomScale > 1.0f) {

        CGFloat height, width;
        height = MIN(CGRectGetHeight(self.imageView.frame) + self.imageView.frame.origin.x, CGRectGetHeight(self.bounds));
        width = MIN(CGRectGetWidth(self.imageView.frame) + self.imageView.frame.origin.y, CGRectGetWidth(self.bounds));
        self.scrollView.frame = CGRectMake((self.bounds.size.width / 2) - (width / 2), (self.bounds.size.height / 2) - (height / 2), width, height);

    } else {

        [self layoutScrollViewAnimated:NO];

    }
}

- (void)layoutScrollViewAnimated:(BOOL)animated {

    if (!_imageView.image) {
        return;
    }

    if (animated) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.0001];
    }

    CGFloat hfactor = self.imageView.image.size.width / self.frame.size.width;
    CGFloat vfactor = self.imageView.image.size.height / self.frame.size.height;

    CGFloat factor = MAX(hfactor, vfactor);

    CGFloat newWidth = (int) (self.imageView.image.size.width / factor);
    CGFloat newHeight = (int) (self.imageView.image.size.height / factor);

    CGFloat leftOffset = (int) ((self.frame.size.width - newWidth) / 2);
    CGFloat topOffset = (int) ((self.frame.size.height - newHeight) / 2);

    self.scrollView.frame = CGRectMake(leftOffset, topOffset, newWidth, newHeight);
    self.scrollView.layer.position = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
    self.scrollView.contentOffset = CGPointMake(0.0f, 0.0f);
    self.imageView.frame = self.scrollView.bounds;

    if (animated) {
        [UIView commitAnimations];
    }
}

#pragma mark - Animation

- (CABasicAnimation*) fadeAnimation
{
    CABasicAnimation* animation = [CABasicAnimation animationWithKeyPath: @"opacity"];
    animation.fromValue = @(0.0f);
    animation.toValue   = @(1.0f);
    animation.duration  = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseOut];
    return animation;
}

#pragma mark - UIScrollViewDelegate

- (void) killZoomAnimationDidStop: (BOOL) finished
{
    if (finished)
    {
        [self.scrollView setZoomScale: 1.0f animated: NO];
        self.imageView.frame = self.scrollView.bounds;
        [self layoutScrollViewAnimated: NO];
    }
}

- (void) killScrollViewZoom
{
    [self killScrollViewZoom: nil];
}

- (void) killScrollViewZoom: (void (^)(BOOL finished)) completion
{
    if (!self.scrollView.zoomScale > 1.0f)
        return;

    if (!self.imageView.image)
        return;


    [UIView animateWithDuration: 0.3
                     animations: ^
                     {
                         CGFloat hfactor = self.imageView.image.size.width  / self.frame.size.width;
                         CGFloat vfactor = self.imageView.image.size.height / self.frame.size.height;

                         CGFloat factor = MAX(hfactor, vfactor);

                         CGFloat newWidth = (int) (self.imageView.image.size.width / factor);
                         CGFloat newHeight = (int) (self.imageView.image.size.height / factor);

                         CGFloat leftOffset = (int) ((self.frame.size.width - newWidth)  / 2.0f);
                         CGFloat topOffset = (int) ((self.frame.size.height - newHeight) / 2.0f);

                         self.scrollView.frame = CGRectMake(leftOffset, topOffset, newWidth, newHeight);
                         self.imageView.frame  = self.scrollView.bounds;
                     }
                     completion: ^(BOOL finished)
                     {
                         [self killZoomAnimationDidStop: finished];
                         if (completion)
                             completion(finished);
                     }];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return [self.scrollView viewWithTag:ZOOM_VIEW_TAG];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {

    if (scrollView.zoomScale > 1.0f) {

        CGFloat height, width;
        height = MIN(CGRectGetHeight(self.imageView.frame) + self.imageView.frame.origin.x, CGRectGetHeight(self.bounds));
        width = MIN(CGRectGetWidth(self.imageView.frame) + self.imageView.frame.origin.y, CGRectGetWidth(self.bounds));


        if (CGRectGetMaxX(self.imageView.frame) > self.bounds.size.width) {
            width = CGRectGetWidth(self.bounds);
        } else {
            width = CGRectGetMaxX(self.imageView.frame);
        }

        if (CGRectGetMaxY(self.imageView.frame) > self.bounds.size.height) {
            height = CGRectGetHeight(self.bounds);
        } else {
            height = CGRectGetMaxY(self.imageView.frame);
        }

        CGRect frame = self.scrollView.frame;
        self.scrollView.frame = CGRectMake((self.bounds.size.width / 2) - (width / 2), (self.bounds.size.height / 2) - (height / 2), width, height);
        self.scrollView.layer.position = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
        if (!CGRectEqualToRect(frame, self.scrollView.frame)) {

            CGFloat offsetY, offsetX;

            if (frame.origin.y < self.scrollView.frame.origin.y) {
                offsetY = self.scrollView.contentOffset.y - (self.scrollView.frame.origin.y - frame.origin.y);
            } else {
                offsetY = self.scrollView.contentOffset.y - (frame.origin.y - self.scrollView.frame.origin.y);
            }

            if (frame.origin.x < self.scrollView.frame.origin.x) {
                offsetX = self.scrollView.contentOffset.x - (self.scrollView.frame.origin.x - frame.origin.x);
            } else {
                offsetX = self.scrollView.contentOffset.x - (frame.origin.x - self.scrollView.frame.origin.x);
            }

            if (offsetY < 0) offsetY = 0;
            if (offsetX < 0) offsetX = 0;

            self.scrollView.contentOffset = CGPointMake(offsetX, offsetY);
            self.scrollView.scrollEnabled = YES;
        }

    } else {
        [self layoutScrollViewAnimated:YES];
        self.scrollView.scrollEnabled = NO;
    }
}

#pragma mark - RotateGesture

- (void)rotate:(UIRotationGestureRecognizer *)gesture {

    if (!_rotationEnabled) {
        return;
    }
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self.layer removeAllAnimations];
        beginRadians = gesture.rotation;
        self.layer.transform = CATransform3DMakeRotation(beginRadians, 0.0f, 0.0f, 1.0f);

    }
    else if (gesture.state == UIGestureRecognizerStateChanged) {
        self.layer.transform = CATransform3DMakeRotation((beginRadians + gesture.rotation), 0.0f, 0.0f, 1.0f);
    }
    else {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
        animation.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        animation.duration = 0.3f;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        animation.delegate = self;
        [animation setValue:[NSNumber numberWithInt:202] forKey:@"AnimationType"];
        [self.layer addAnimation:animation forKey:@"RotateAnimation"];
    }
}

- (void) animationDidStop: (CAAnimation*) anim finished: (BOOL) flag
{
    if (flag)
    {
        if ([[anim valueForKey: @"AnimationType"] integerValue] == 101)
        {
            [self resetBackgroundColors];
        }
        else if ([[anim valueForKey: @"AnimationType"] integerValue] == 202)
        {
            self.layer.transform = CATransform3DIdentity;
        }
    }
}

#pragma mark - Bars

- (void)toggleBars {
    [[NSNotificationCenter defaultCenter] postNotificationName:kFSImageViewerToogleBarsNotificationKey object:nil];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    UITouch *touch = [touches anyObject];

    if (touch.tapCount == 1) {
        [self performSelector:@selector(toggleBars) withObject:nil afterDelay:.2];
    }
}


@end
