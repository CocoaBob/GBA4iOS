//
//  GBAEmulatorScreen.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulatorScreen.h"

@implementation GBAEmulatorScreen

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
    }
    
    return self;
}

- (CGSize)intrinsicContentSize
{    
    return self.eaglView.bounds.size;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.eaglView.center = CGPointMake(roundf(self.bounds.size.width/2.0f), roundf(self.bounds.size.height/2.0f));
    self.eaglView.frame = CGRectIntegral(self.eaglView.frame);
    
    self.introAnimationLayer.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
}

- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates
{
    BOOL success = [super drawViewHierarchyInRect:rect afterScreenUpdates:afterUpdates];
    
    if (self.introAnimationLayer)
    {
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:self.introAnimationLayer.player.currentItem.asset];
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        imageGenerator.appliesPreferredTrackTransform = YES;
        
        NSError *error = nil;
        CGImageRef currentFrame = [imageGenerator copyCGImageAtTime:self.introAnimationLayer.player.currentItem.currentTime actualTime:nil error:&error];
        
        if (currentFrame != NULL)
        {
            UIImage *image = [UIImage imageWithCGImage:currentFrame];
            CGImageRelease(currentFrame);
            
            CGRect videoRect = AVMakeRectWithAspectRatioInsideRect(image.size, rect);
            [image drawInRect:videoRect];
        }
        else
        {
            ELog(error);
        }

    }
    
    return success;
}


#pragma mark - Getters/Setters

- (void)setEaglView:(UIView *)eaglView
{
#if !(TARGET_IPHONE_SIMULATOR)
    _eaglView = (EAGLView *)eaglView;
#else
    _eaglView = eaglView;
#endif
    
    [self addSubview:_eaglView];
}

- (void)setIntroAnimationLayer:(AVPlayerLayer *)introAnimationLayer
{
    [_introAnimationLayer.player pause];
    [_introAnimationLayer removeFromSuperlayer];
    _introAnimationLayer = introAnimationLayer;
    
    [self.layer addSublayer:introAnimationLayer];
}

@end
