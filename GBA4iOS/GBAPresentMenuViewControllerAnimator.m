//
//  GBAPresentMenuViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAPresentMenuViewControllerAnimator.h"

@implementation GBAPresentMenuViewControllerAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.6;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
    UIViewController *destinationViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    GBAEmulationViewController *initialViewController = (GBAEmulationViewController *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    initialViewController.showBlurredSnapshot = YES;
    initialViewController.blurredSnapshot.alpha = 0.0;
    
    UIView *destinationView = [destinationViewController view];
    UIView *initialView = [initialViewController view];
    
    initialView.frame = [transitionContext initialFrameForViewController:initialViewController];
    initialView.alpha = 1.0f;
    [[transitionContext containerView] addSubview:initialView];
    
    destinationView.frame = [transitionContext initialFrameForViewController:initialViewController];
    destinationView.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    destinationView.alpha = 0.0;
    [[transitionContext containerView] addSubview:destinationView];
    
    self.emulationViewController = (GBAEmulationViewController *)initialViewController;
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
        destinationView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        destinationView.alpha = 1.0f;
        initialViewController.blurredSnapshot.alpha = 1.0f;
    } completion:^(BOOL finished) {
        
        if (self.completionBlock)
        {
            self.completionBlock();
        }
        
        [transitionContext completeTransition:YES];
    }];
}

@end
