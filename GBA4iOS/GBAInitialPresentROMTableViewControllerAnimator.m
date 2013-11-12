//
//  GBAInitialPresentROMTableViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAInitialPresentROMTableViewControllerAnimator.h"
#import "GBAEmulationViewController.h"

@implementation GBAInitialPresentROMTableViewControllerAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    if (self.presenting)
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
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    if (self.presenting)
    {
        [[transitionContext containerView] addSubview:toViewController.view];
        
        toViewController.view.frame = [transitionContext initialFrameForViewController:fromViewController];
        toViewController.view.alpha = 1.0;
        
        fromViewController.view.layer.allowsGroupOpacity = YES;
        
        [[transitionContext containerView] addSubview:fromViewController.view];
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            fromViewController.view.alpha = 0.0;
        } completion:^(BOOL finished) {
            [fromViewController.view removeFromSuperview];
            fromViewController.view.alpha = 1.0;
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
    else
    {
        // Below make sure the view is laid out correctly
        UIInterfaceOrientation interfaceOrientation = toViewController.interfaceOrientation;
        [(GBAEmulationViewController *)toViewController refreshLayout];
        
        CGAffineTransform initialToTransform = toViewController.view.transform;
        CGAffineTransform initialFromTransform = fromViewController.view.transform;
        
        [[transitionContext containerView] insertSubview:toViewController.view atIndex:0];
        
        toViewController.view.frame = [transitionContext initialFrameForViewController:fromViewController]; // Set the initial frame to where it'll end up, then we simply transform it
        
        toViewController.view.transform = CGAffineTransformConcat(initialToTransform, CGAffineTransformMakeScale(0.5, 0.5));
        
        fromViewController.view.layer.allowsGroupOpacity = YES; // Better animation
        
        [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
            toViewController.view.transform = CGAffineTransformConcat(initialToTransform, CGAffineTransformMakeScale(1.0, 1.0));
            
            fromViewController.view.alpha = 0.0;
            fromViewController.view.transform = CGAffineTransformConcat(initialFromTransform, CGAffineTransformMakeScale(2.0, 2.0));
            
            [[UIApplication sharedApplication] setStatusBarHidden:[toViewController prefersStatusBarHidden] withAnimation:UIStatusBarAnimationNone];
            
        } completion:^(BOOL finished) {
            
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
            
        }];
    }
    
    
    
}

@end
