//
//  GBACalloutView.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/25/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACalloutView.h"

@interface GBACalloutView () <UIGestureRecognizerDelegate>

@end

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
        panGestureRecognzier.delegate = self;
        [self addGestureRecognizer:panGestureRecognzier];
    }
    return self;
}

#pragma mark - Gesture Recognizers

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([self.interactionDelegate respondsToSelector:@selector(calloutViewShouldBeginTranslating:)])
    {
        return [self.interactionDelegate calloutViewShouldBeginTranslating:self];
    }
    
    return YES;
}

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

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    GBACalloutView *calloutView = [GBACalloutView new];
    calloutView.title = [self.title copy];
    calloutView.subtitle = [self.subtitle copy];
    calloutView.delegate = self.delegate;
    
    return calloutView;
}

#pragma mark - Subclassing

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    // Unlike SMCalloutView, we *want* to be able to be interact with GBACalloutView
    return CGRectContainsPoint(self.bounds, point);
}

@end
