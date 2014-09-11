//
//  GBALinkNearbyPeersHeaderFooterView.m
//  GBA4iOS
//
//  Created by Riley Testut on 4/12/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBALinkNearbyPeersHeaderFooterView.h"

@interface GBALinkNearbyPeersHeaderFooterView ()

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation GBALinkNearbyPeersHeaderFooterView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _activityIndicatorView = ({
            UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicatorView.hidesWhenStopped = YES;
            activityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
            activityIndicatorView;
        });
        [self.contentView addSubview:_activityIndicatorView];
    }
    return self;
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

- (void)updateConstraints
{
    [self layoutIfNeeded]; // Ensures the textLabel has been added as a subview
    
    NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:[textLabel]-[activityIndicatorView]" options:0 metrics:nil views:@{@"textLabel": self.textLabel, @"activityIndicatorView": self.activityIndicatorView}];
    
    [self addConstraints:constraints];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicatorView
                                                     attribute:NSLayoutAttributeCenterY
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.textLabel
                                                     attribute:NSLayoutAttributeCenterY
                                                    multiplier:1.0
                                                      constant:0.0]];
    
    [super updateConstraints];
}

#pragma mark - Getters/Setters

- (void)setShowsActivityIndicator:(BOOL)showsActivityIndicator
{
    _showsActivityIndicator = showsActivityIndicator;
    
    if (showsActivityIndicator)
    {
        [self.activityIndicatorView startAnimating];
    }
    else
    {
        [self.activityIndicatorView stopAnimating];
    }
}

@end
