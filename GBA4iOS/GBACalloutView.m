//
//  GBACalloutView.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/25/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACalloutView.h"

@implementation GBACalloutView
{
    CGPoint _initialCenterForDraggedCalloutView;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) 
    {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDetectTap:)];
        [self addGestureRecognizer:tapGestureRecognizer];
        
        UIPanGestureRecognizer *panGestureRecognzier = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didDetectPan:)];
        [self addGestureRecognizer:panGestureRecognzier];
    }
    return self;
}

#pragma mark - Gesture Recognizers

- (void)didDetectTap:(UITapGestureRecognizer *)tapGestureRecognizer
{
    if ([self.interactionDelegate respondsToSelector:@selector(calloutViewWasTapped:)])
    {
        [self.interactionDelegate calloutViewWasTapped:self];
    }
}

- (void)didDetectPan:(UIPanGestureRecognizer *)panGestureRecognizer
{
    switch (panGestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _initialCenterForDraggedCalloutView = self.center;
            
            if ([self.interactionDelegate respondsToSelector:@selector(calloutViewWillBeginTranslating:)])
            {
                [self.interactionDelegate calloutViewWillBeginTranslating:self];
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [panGestureRecognizer translationInView:self.superview];
            self.center = CGPointMake(_initialCenterForDraggedCalloutView.x + translation.x, _initialCenterForDraggedCalloutView.y + translation.y);
            
            if ([self.interactionDelegate respondsToSelector:@selector(calloutView:didTranslate:)])
            {
                [self.interactionDelegate calloutView:self didTranslate:translation];
            }
            
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            if ([self.interactionDelegate respondsToSelector:@selector(calloutViewDidFinishTranslating:)])
            {
                [self.interactionDelegate calloutViewDidFinishTranslating:self];
            }
        }
            
        default:
            break;
    }

}

#pragma mark - Subclassing

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    // Unlike SMCalloutView, we *want* to be able to be interact with GBACalloutView
    return CGRectContainsPoint(self.bounds, point);
}

@end
