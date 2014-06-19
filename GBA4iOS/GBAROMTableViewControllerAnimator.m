//
//  GBAROMTableViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/8/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROMTableViewControllerAnimator.h"
#import "GBAEmulationViewController.h"
#import "GBAROMTableViewController.h"

@implementation GBAROMTableViewControllerAnimator

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
    
    BOOL extendedStatusBar = ([[UIApplication sharedApplication] statusBarFrame].size.height == 40.f);
    
    if ([self isPresenting])
    {
        [[transitionContext containerView] addSubview:toViewController.view];
        
        CGAffineTransform transform = toViewController.view.transform;
        
        toViewController.view.frame = [transitionContext initialFrameForViewController:fromViewController];
        
        if (extendedStatusBar)
        {
            toViewController.view.frame = ({
                CGRect frame = toViewController.view.frame;
                frame.origin.y += 40.0f;
                frame;
            });
        }
        
        toViewController.view.alpha = 0.0;
        toViewController.view.transform = CGAffineTransformScale(transform, 2.0, 2.0);
        
        [(GBAEmulationViewController *)fromViewController blurWithInitialAlpha:0.0];
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            toViewController.view.alpha = 1.0;
            toViewController.view.transform = CGAffineTransformScale(transform, 1.0, 1.0);
            
            [(GBAEmulationViewController *)fromViewController setBlurAlpha:1.0];
        } completion:^(BOOL finished) {
            
            if (extendedStatusBar)
            {
                toViewController.view.frame = ({
                    CGRect frame = toViewController.view.frame;
                    frame.origin.y -= 20.0f;
                    frame;
                });
            }
            
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    else
    {
        [[transitionContext containerView] addSubview:fromViewController.view];
        
        CGAffineTransform transform = fromViewController.view.transform;
        CGRect frame = [transitionContext initialFrameForViewController:fromViewController];
        
        fromViewController.view.transform = CGAffineTransformScale(transform, 1.0, 1.0);
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            fromViewController.view.alpha = 0.0;
            fromViewController.view.transform = CGAffineTransformScale(transform, 2.0, 2.0);
            
            [(GBAEmulationViewController *)toViewController setBlurAlpha:0.0];
        } completion:^(BOOL finished) {
            fromViewController.view.transform = CGAffineTransformScale(transform, 1.0, 1.0);
            fromViewController.view.frame = frame;
            
            [(GBAEmulationViewController *)toViewController removeBlur];
            
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
        
    }
}


@end
