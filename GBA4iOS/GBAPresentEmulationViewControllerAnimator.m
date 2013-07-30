//
//  GBAPresentEmulationViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAPresentEmulationViewControllerAnimator.h"

@implementation GBAPresentEmulationViewControllerAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.6;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
    UIViewController *destinationViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *initialViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    UIView *destinationView = [destinationViewController view];
    UIView *initialView = [initialViewController view];
    
    destinationView.frame = [transitionContext initialFrameForViewController:initialViewController];
    destinationView.transform = CGAffineTransformMakeScale(0.50, 0.50);
    [transitionContext.containerView addSubview:destinationView];
    
    initialView.frame = [transitionContext initialFrameForViewController:initialViewController];
    [transitionContext.containerView addSubview:initialView];
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        initialView.alpha = 0.0;
        initialView.transform = CGAffineTransformMakeScale(2.0, 2.0);
        destinationView.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:^(BOOL finished) {
        [transitionContext completeTransition:YES];
    }];
}

@end
