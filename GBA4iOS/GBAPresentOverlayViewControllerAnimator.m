//
//  GBAPresentOverlayViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAPresentOverlayViewControllerAnimator.h"
#import "GBAEmulationViewController.h"

@implementation GBAPresentOverlayViewControllerAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    return 0.4;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    
    [[UIApplication sharedApplication] setStatusBarStyle:[toViewController preferredStatusBarStyle] animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:[toViewController prefersStatusBarHidden] withAnimation:UIStatusBarAnimationFade];
    
    if ([self isPresenting])
    {
        __block CGRect finalFrame = [transitionContext initialFrameForViewController:fromViewController];
        CGRect frame = finalFrame;
        
        toViewController.view.frame = frame;
        
        [[transitionContext containerView] addSubview:toViewController.view];
        
        if ([[UIScreen mainScreen] respondsToSelector:@selector(fixedCoordinateSpace)])
        {
            frame.origin.y = CGRectGetHeight(frame);
        }
        else
        {
            if (UIInterfaceOrientationIsPortrait(fromViewController.interfaceOrientation))
            {
                frame.origin.y = CGRectGetHeight(frame);
            }
            else
            {
                frame.origin.x = -CGRectGetWidth(frame);
            }
        }
        
        BOOL extendedStatusBar = ([[UIApplication sharedApplication] statusBarFrame].size.height == 40.f);
        
        if (extendedStatusBar)
        {
            finalFrame.origin.y += 40.0f;
        }
        
        toViewController.view.frame = frame;
        
        [(GBAEmulationViewController *)fromViewController blurWithInitialAlpha:1.0];
        [(GBAEmulationViewController *)fromViewController blurredContentsImageView].frame = CGRectMake(0, CGRectGetHeight(fromViewController.view.bounds), CGRectGetWidth(fromViewController.view.bounds), 0);
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 options:7 << 16 animations:^{
            // Don't animate the view explicitly, because for whatever reason animating the status bar does this for us. Yay iOS 7 weirdness.
            toViewController.view.frame = finalFrame;
            
            [(GBAEmulationViewController *)fromViewController blurredContentsImageView].frame = CGRectMake(0, 0, CGRectGetWidth(fromViewController.view.bounds), CGRectGetHeight(fromViewController.view.bounds));
        } completion:^(BOOL finished) {
            
            if (extendedStatusBar)
            {
                finalFrame.origin.y -= 20.0f;
            }
            
            toViewController.view.frame = finalFrame;
            
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    else
    {
        CGRect frame = [transitionContext initialFrameForViewController:fromViewController];
        
        if ([[UIScreen mainScreen] respondsToSelector:@selector(fixedCoordinateSpace)])
        {
            frame.origin.y = CGRectGetHeight(frame);
        }
        else
        {
            if (UIInterfaceOrientationIsPortrait(fromViewController.interfaceOrientation))
            {
                frame.origin.y = CGRectGetHeight(frame);
            }
            else
            {
                frame.origin.x = -CGRectGetWidth(frame);
            }
        }
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 options:7 << 16 animations:^{
            fromViewController.view.frame = frame;
            
            [(GBAEmulationViewController *)toViewController blurredContentsImageView].frame = CGRectMake(0, CGRectGetHeight(fromViewController.view.bounds), CGRectGetWidth(fromViewController.view.bounds), 0);
            
        } completion:^(BOOL finished) {
            [(GBAEmulationViewController *)toViewController removeBlur];
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
}

@end
