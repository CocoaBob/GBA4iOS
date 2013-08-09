//
//  GBAPresentMenuViewControllerAnimator.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAPresentMenuViewControllerAnimator.h"
@import QuartzCore;

@implementation GBAPresentMenuViewControllerAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.6;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *destinationViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    GBAEmulationViewController *initialViewController = (GBAEmulationViewController *)[transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    [initialViewController blurWithInitialAlpha:0.0];
    
    UIView *destinationView = [destinationViewController view];
    UIView *initialView = [initialViewController view];
    
    initialView.frame = [transitionContext initialFrameForViewController:initialViewController];
    initialView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    initialView.alpha = 1.0f;
    [[transitionContext containerView] addSubview:initialView];
    
    initialView.frame = ({
        CGRect frame = initialView.frame;
        frame.origin.y = 0.5; // Can't be zero, I have no idea why
        frame;
    });
    
    destinationView.frame = [transitionContext initialFrameForViewController:initialViewController];
    destinationView.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    destinationView.alpha = 0.0;
    [[transitionContext containerView] addSubview:destinationView];
    
    self.emulationViewController = (GBAEmulationViewController *)initialViewController;
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
        destinationView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        destinationView.alpha = 1.0f;
        initialView.transform = CGAffineTransformMakeScale(0.50f, 0.50f);
        initialViewController.blurAlpha = 1.0f;
    } completion:^(BOOL finished) {
        
        if (self.completionBlock)
        {
            self.completionBlock();
        }
        
        [transitionContext completeTransition:YES];
    }];
}

@end
