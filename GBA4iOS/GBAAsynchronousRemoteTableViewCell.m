//
//  GBAAsynchronousRemoteTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAAsynchronousRemoteTableViewCell.h"
#import "UIImage+RSTResizing.h"

#import <AFNetworking/UIImageView+AFNetworking.h>

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
    
    rst_dispatch_sync_on_main_thread(^{
        self.activityIndicatorView = ({
            UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicatorView.center = CGPointMake(self.contentView.bounds.size.width/2.0f, self.contentView.bounds.size.height/2.0f);
            activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            activityIndicatorView.hidesWhenStopped = YES;
            [activityIndicatorView startAnimating];
            [self.contentView addSubview:activityIndicatorView];
            activityIndicatorView;
        });
    });
}

- (void)prepareForReuse
{
    [self.backgroundImageView cancelImageRequestOperation];
    self.backgroundImageView.image = nil;
    self.backgroundImageView.alpha = 0.0;
    self.imageURL = nil;
    self.activityIndicatorView.alpha = 1.0f;
    [self.activityIndicatorView startAnimating];
    
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
    [self layoutIfNeeded];
    
    if ([self.imageCache objectForKey:self.imageURL])
    {
        UIImage *image = [self.imageCache objectForKey:self.imageURL];
        rst_dispatch_sync_on_main_thread(^{
            [self displayImage:image animated:NO];
        });
    }
    
    [self loadRemoteImage];
}

- (void)loadRemoteImage
{
    NSURLRequest *request = [NSURLRequest requestWithURL:self.imageURL];
    
    __weak __typeof__(self) weakSelf = self;
    [self.backgroundImageView setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf prepareAndDisplayImage:image];
        });
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
        DLog(@"Failure :( %@", error);
    }];
}

- (void)prepareAndDisplayImage:(UIImage *)image
{
    image = [image imageByResizingToFitSize:self.backgroundImageView.bounds.size opaque:YES];
    [self.imageCache setObject:image forKey:self.imageURL];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self displayImage:image animated:YES];
    });
}

- (void)displayImage:(UIImage *)image animated:(BOOL)animated
{
    void (^animationBlock)(void) = ^{
        self.activityIndicatorView.alpha = 0.0;
        self.backgroundImageView.alpha = 1.0;
    };
    
    self.backgroundImageView.image = image;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:animationBlock completion:^(BOOL finished) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicatorView stopAnimating];
            });
        }];
    }
    else
    {
        animationBlock();
        rst_dispatch_sync_on_main_thread(^{
            [self.activityIndicatorView stopAnimating];
        });
    }
    
}


#pragma mark - Getters/Setters

- (void)setImageURL:(NSURL *)imageURL
{
    _imageURL = imageURL;
    
    [self update];
}

@end
