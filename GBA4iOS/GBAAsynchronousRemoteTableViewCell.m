//
//  GBAAsynchronousRemoteTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAAsynchronousRemoteTableViewCell.h"
#import "UIImage+RSTResizing.h"

#import <AFNetworking/AFNetworking.h>
#import "GBAControllerSkinImageResponseSerializer.h"

@interface GBAAsynchronousRemoteTableViewCell ()

@property (strong, nonatomic) UIImageView *backgroundImageView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (strong, nonatomic) NSURLSessionDataTask *imageDataTask;

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
    [super prepareForReuse];
    
    [self.imageDataTask cancel];
    self.imageDataTask = nil;
    
    rst_dispatch_sync_on_main_thread(^{
        self.backgroundImageView.image = nil;
        self.backgroundImageView.alpha = 0.0;
        
        self.activityIndicatorView.alpha = 1.0f;
        [self.activityIndicatorView startAnimating];
    });
    
    self.imageURL = nil;
    
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
    __block NSURLRequest *request = [NSURLRequest requestWithURL:self.imageURL];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    CGSize windowSize = [[[UIApplication sharedApplication] delegate] window].bounds.size;
    
    if (windowSize.width > windowSize.height)
    {
        windowSize = CGSizeMake(windowSize.height, windowSize.width);
    }
    
    GBAControllerSkinImageResponseSerializer *serializer = [GBAControllerSkinImageResponseSerializer serializer];
    serializer.resizableImageTargetSize = windowSize;
    
    manager.responseSerializer = serializer;
    
    __weak __typeof__(self) weakSelf = self;
    self.imageDataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, UIImage *image, NSError *error) {
        
        if ([error code] == NSURLErrorCancelled)
        {
            return;
        }
        
        if (error || image == nil)
        {
            DLog(@"Failure :( %@", error);
            return;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf prepareAndDisplayImage:image imageCacheKey:request.URL];
        });
        
    }];
    
    [self.imageDataTask resume];
}

- (void)prepareAndDisplayImage:(UIImage *)image imageCacheKey:(id<NSCopying>)key
{
    image = [image imageByResizingToFitSize:self.backgroundImageView.bounds.size opaque:YES];
    [self.imageCache setObject:image forKey:key];
    
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
