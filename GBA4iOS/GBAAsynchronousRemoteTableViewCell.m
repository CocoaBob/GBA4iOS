//
//  GBAAsynchronousRemoteTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAAsynchronousRemoteTableViewCell.h"

@interface GBAAsynchronousRemoteTableViewCell ()

@property (strong, nonatomic) UIImageView *backgroundImageView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation GBAAsynchronousRemoteTableViewCell

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (void)initialize
{
    self.backgroundImageView = ({
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height)];
        imageView.alpha = 0.0;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:imageView];
        imageView;
    });
    
    self.activityIndicatorView = ({
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityIndicatorView.center = CGPointMake(self.contentView.bounds.size.width/2.0f, self.contentView.bounds.size.height/2.0f);
        activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        activityIndicatorView.hidesWhenStopped = YES;
        [activityIndicatorView startAnimating];
        [self.contentView addSubview:activityIndicatorView];
        activityIndicatorView;
    });
}

- (void)prepareForReuse
{
    self.backgroundImageView.image = nil;
    self.backgroundImageView.alpha = 0.0;
    self.imageURL = nil;
    self.activityIndicatorView.alpha = 1.0f;
    
    [self setEditing:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

#pragma mark - Download Image

- (void)update
{
    
}

#pragma mark - Getters/Setters

- (void)setImageURL:(NSURL *)imageURL
{
    _imageURL = imageURL;
    
    [self update];
}

@end
