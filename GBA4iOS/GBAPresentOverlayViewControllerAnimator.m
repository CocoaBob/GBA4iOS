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
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    CGAffineTransform initialTransform = toViewController.view.transform;
    
    CGRect rect = [transitionContext initialFrameForViewController:fromViewController];
    
    [[UIApplication sharedApplication] setStatusBarStyle:[toViewController preferredStatusBarStyle] animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:[toViewController prefersStatusBarHidden] withAnimation:UIStatusBarAnimationFade];
    
    if ([self isPresenting])
    {
        toViewController.view.frame = [transitionContext initialFrameForViewController:fromViewController];
        
        [[transitionContext containerView] addSubview:toViewController.view];
        
        if (UIInterfaceOrientationIsPortrait(fromViewController.interfaceOrientation))
        {
            rect.origin.y = CGRectGetHeight(fromViewController.view.frame);
        }
        else
        {
            rect.origin.x = -CGRectGetHeight(fromViewController.view.frame);
        }
        
        toViewController.view.frame = rect;
        
        [(GBAEmulationViewController *)fromViewController setBlurAlpha:1.0]; // Don't need to animate
        [(GBAEmulationViewController *)fromViewController blurredContentsImageView].frame = CGRectMake(0, CGRectGetHeight(fromViewController.view.bounds), CGRectGetWidth(fromViewController.view.bounds), 0);
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [(GBAEmulationViewController *)fromViewController blurredContentsImageView].frame = CGRectMake(0, 0, CGRectGetWidth(fromViewController.view.bounds), CGRectGetHeight(fromViewController.view.bounds));
            toViewController.view.frame = CGRectMake(0, 0, CGRectGetWidth(toViewController.view.frame), CGRectGetHeight(toViewController.view.frame));
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
            
        }];
    }
    else
    {
        [[transitionContext containerView] insertSubview:toViewController.view atIndex:0];
        
        if (UIInterfaceOrientationIsPortrait(fromViewController.interfaceOrientation))
        {
            rect.origin.y = CGRectGetHeight(fromViewController.view.frame);
        }
        else
        {
            rect.origin.x = -CGRectGetHeight(fromViewController.view.frame);
        }
        
        fromViewController.view.frame = CGRectMake(0, 0, CGRectGetWidth(fromViewController.view.frame), CGRectGetHeight(fromViewController.view.frame));
        
        [(GBAEmulationViewController *)toViewController refreshLayout];
        [(GBAEmulationViewController *)toViewController blurredContentsImageView].frame = CGRectMake(0, 0, CGRectGetWidth(fromViewController.view.bounds), CGRectGetHeight(fromViewController.view.bounds));
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [(GBAEmulationViewController *)toViewController blurredContentsImageView].frame = CGRectMake(0, CGRectGetHeight(toViewController.view.bounds), CGRectGetWidth(toViewController.view.bounds), 0);
            fromViewController.view.frame = rect;
        } completion:^(BOOL finished) {
            [(GBAEmulationViewController *)toViewController removeBlur];
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    
}

@end
