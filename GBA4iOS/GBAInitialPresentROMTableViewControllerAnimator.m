//
//  GBAInitialPresentROMTableViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAInitialPresentROMTableViewControllerAnimator.h"

@implementation GBAInitialPresentROMTableViewControllerAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    if ([self isPresenting])
    {
        return 0.4;
    }
    else
    {
        return 0.6;
    }
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    if ([self isPresenting])
    {
        toViewController.view.frame = [transitionContext initialFrameForViewController:fromViewController];
        toViewController.view.alpha = 0.0;
        
        toViewController.view.layer.allowsGroupOpacity = YES;
        
        [[transitionContext containerView] addSubview:toViewController.view];
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            toViewController.view.alpha = 1.0;
        } completion:^(BOOL finished) {
            fromViewController.view.alpha = 1.0;
            toViewController.view.layer.allowsGroupOpacity = NO;
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    else
    {
        // When there's the double-height status bar, iOS 7 totally botches the normal animation, so we put the fromViewController in a container view and animate that
        UIView *fromContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([transitionContext containerView].bounds), CGRectGetHeight([transitionContext containerView].bounds))];
        [fromContainerView addSubview:fromViewController.view];
        
        [[transitionContext containerView] addSubview:fromContainerView];
        
        fromContainerView.layer.allowsGroupOpacity = YES; // Better animation
        
        CGAffineTransform fromTransform = fromContainerView.transform;
        CGAffineTransform toTransform = toViewController.view.transform;
        
        toViewController.view.transform = CGAffineTransformScale(toTransform, 0.5, 0.5);
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            fromContainerView.transform = CGAffineTransformScale(fromTransform, 2.0, 2.0);
            fromContainerView.alpha = 0.0;
            
            toViewController.view.transform = CGAffineTransformScale(toTransform, 1.0, 1.0);
            
        } completion:^(BOOL finished) {
            fromContainerView.layer.allowsGroupOpacity = NO;
            fromContainerView.transform = CGAffineTransformScale(fromTransform, 1.0, 1.0);
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    
    [[UIApplication sharedApplication] setStatusBarHidden:[toViewController prefersStatusBarHidden] withAnimation:UIStatusBarAnimationFade];
    [[UIApplication sharedApplication] setStatusBarStyle:[toViewController preferredStatusBarStyle]];
}

@end
