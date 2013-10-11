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
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    toViewController.view.frame = [transitionContext initialFrameForViewController:fromViewController]; // Set the initial frame to where it'll end up, then we simply transform it
    
    CGAffineTransform initialTransform = toViewController.view.transform;
    
    if ([self isPresenting])
    {
        [[transitionContext containerView] addSubview:toViewController.view];
        
        toViewController.view.alpha = 0;
        toViewController.view.transform = CGAffineTransformConcat(initialTransform, CGAffineTransformMakeScale(2.0, 2.0));
        
        [(GBAEmulationViewController *)fromViewController blurWithInitialAlpha:0.0f darkened:YES];
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            [(GBAEmulationViewController *)fromViewController setBlurAlpha:1.0f];
            
            toViewController.view.alpha = 1;
            toViewController.view.transform = CGAffineTransformConcat(initialTransform, CGAffineTransformMakeScale(1.0, 1.0));
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
            
        }];
    }
    else
    {
        [[transitionContext containerView] insertSubview:toViewController.view atIndex:0];
        
        [(GBAEmulationViewController *)toViewController resumeEmulation];
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            [(GBAEmulationViewController *)toViewController setBlurAlpha:0.0f];
            
            fromViewController.view.alpha = 0.0;
            fromViewController.view.transform = CGAffineTransformConcat(initialTransform, CGAffineTransformMakeScale(2.0, 2.0));
        } completion:^(BOOL finished) {
             [(GBAEmulationViewController *)toViewController removeBlur];
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
            
        }];
    }
    
}

@end
