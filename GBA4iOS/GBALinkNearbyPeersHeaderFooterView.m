//
//  GBALinkNearbyPeersHeaderFooterView.m
//  GBA4iOS
//
//  Created by Riley Testut on 4/12/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBALinkNearbyPeersHeaderFooterView.h"

@interface GBALinkNearbyPeersHeaderFooterView ()
{
    BOOL _hasAddedInitialConstraints;
}

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation GBALinkNearbyPeersHeaderFooterView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initActivityIndicator];
        self.textLabel.text = @" ";
    }
    return self;
}

- (void)initActivityIndicator
{
        self.activityIndicatorView = ({
            UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicatorView.hidesWhenStopped = YES;
            activityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
            activityIndicatorView;
        });
        [self.contentView addSubview:self.activityIndicatorView];
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
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
