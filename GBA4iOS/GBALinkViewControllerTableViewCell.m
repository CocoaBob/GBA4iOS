//
//  GBALinkViewControllerTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 4/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBALinkViewControllerTableViewCell.h"

@interface GBALinkViewControllerTableViewCell ()

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation GBALinkViewControllerTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    if (self)
    {
        _activityIndicatorView = ({
            UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicatorView.hidesWhenStopped = YES;
            activityIndicatorView;
        });
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.textLabel.textColor = [UIColor blackColor];
    self.detailTextLabel.text = nil;
    
    self.showsActivityIndicator = NO;
}

- (void)layoutSubviews 
{
    [super layoutSubviews];
    
    [self.detailTextLabel sizeToFit];
    
    CGFloat padding = self.textLabel.frame.origin.x;
    CGFloat paddingMultiplier = 3;
    
    if (self.accessoryType != UITableViewCellAccessoryNone)
    {
        paddingMultiplier = 2;
    }
    
    CGFloat maximumWidth = self.contentView.bounds.size.width - (self.detailTextLabel.bounds.size.width + padding * paddingMultiplier);
    
    self.textLabel.frame = CGRectMake(self.textLabel.frame.origin.x, self.textLabel.frame.origin.y, maximumWidth, self.textLabel.frame.size.height);
    self.detailTextLabel.frame = CGRectMake(CGRectGetMaxX(self.textLabel.frame) + padding, self.detailTextLabel.frame.origin.y, self.detailTextLabel.frame.size.width, self.detailTextLabel.frame.size.height);
}

#pragma mark - Getters/Setters

- (void)setShowsActivityIndicator:(BOOL)showActivityIndicator
{
    _showsActivityIndicator = showActivityIndicator;
    
    if (showActivityIndicator)
    {
        self.accessoryView = self.activityIndicatorView;
        [self.activityIndicatorView startAnimating];
    }
    else
    {
        self.accessoryView = nil;
        [self.activityIndicatorView stopAnimating];
    }
}

@end
