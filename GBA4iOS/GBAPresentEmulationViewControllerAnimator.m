//
//  GBAPresentEmulationViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAPresentEmulationViewControllerAnimator.h"

@implementation GBAPresentEmulationViewControllerAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    return 0.6;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    // Below make sure the view is laid out correctly
    UIInterfaceOrientation interfaceOrientation = toViewController.interfaceOrientation;
    [toViewController willRotateToInterfaceOrientation:fromViewController.interfaceOrientation duration:0];
    [toViewController willAnimateRotationToInterfaceOrientation:fromViewController.interfaceOrientation duration:0];
    [toViewController didRotateFromInterfaceOrientation:interfaceOrientation];
    
    CGAffineTransform initialToTransform = toViewController.view.transform;
    CGAffineTransform initialFromTransform = fromViewController.view.transform;
    
    toViewController.view.frame = [transitionContext initialFrameForViewController:fromViewController]; // Set the initial frame to where it'll end up, then we simply transform it
    
    [[transitionContext containerView] insertSubview:toViewController.view atIndex:0];
    
    toViewController.view.transform = CGAffineTransformConcat(initialToTransform, CGAffineTransformMakeScale(0.5, 0.5));
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
        toViewController.view.transform = CGAffineTransformConcat(initialToTransform, CGAffineTransformMakeScale(1.0, 1.0));
        
        fromViewController.view.alpha = 0.0;
        fromViewController.view.transform = CGAffineTransformConcat(initialFromTransform, CGAffineTransformMakeScale(2.0, 2.0));
    } completion:^(BOOL finished) {
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        
    }];
    
}

@end
