//
//  GBAAsynchronousImageTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAAsynchronousLocalImageTableViewCell.h"
#import "UIImage+RSTResizing.h"

#define CANCEL_OPERATION_IF_NEEDED(operation) if ([operation isCancelled]) { return; }

@interface GBAAsynchronousLocalImageTableViewCell ()

@property (strong, nonatomic) UIImageView *backgroundImageView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (strong, nonatomic) NSOperationQueue *operationQueue;

@end

@implementation GBAAsynchronousLocalImageTableViewCell

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
    
    self.operationQueue = ({
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        queue.name = @"com.rileytestut.GBA4iOS.asynchronous_cell_queue";
        queue;
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
    [super prepareForReuse];
    
    self.backgroundImageView.image = nil;
    self.backgroundImageView.alpha = 0.0;
    self.image = nil;
    self.imageURL = nil;
    self.activityIndicatorView.alpha = 1.0f;
    self.cacheKey = nil;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

#pragma mark - Update

- (void)update
{
    [self layoutIfNeeded];
    
    if ([self.imageCache objectForKey:self.imageURL] || [self.imageCache objectForKey:self.cacheKey])
    {
        self.loadSynchronously = YES;
    }
    
    [self.activityIndicatorView startAnimating];
    
    [self.operationQueue cancelAllOperations];
    
    NSBlockOperation *blockOperation = [[NSBlockOperation alloc] init];
    __weak NSOperation *weakOperation = blockOperation;
    
    [blockOperation addExecutionBlock:^{
        if (self.image)
        {
            [self prepareAndDisplayImage:self.image withOperation:weakOperation];
        }
        else if (self.imageURL)
        {
            [self loadLocalImageWithOperation:weakOperation];
        }
        
    }];
    
    [self.operationQueue addOperation:blockOperation];
    
    if (self.loadSynchronously)
    {
        [blockOperation waitUntilFinished];
    }
}

- (void)loadLocalImageWithOperation:(NSOperation *)operation
{
    CANCEL_OPERATION_IF_NEEDED(operation);
    
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:[self.imageURL absoluteString]];
    
    CANCEL_OPERATION_IF_NEEDED(operation);
    
    [self prepareAndDisplayImage:image withOperation:operation];
}

- (void)prepareAndDisplayImage:(UIImage *)image withOperation:(NSOperation *)operation
{
    CANCEL_OPERATION_IF_NEEDED(operation);
    
    id key = self.imageURL;
    UIImage *preparedImage = [self.imageCache objectForKey:key];
    
    if (preparedImage == nil)
    {
        key = self.cacheKey;
        preparedImage = [self.imageCache objectForKey:key];
    }
    
    if (preparedImage == nil)
    {
        preparedImage = [image imageByResizingToFitSize:self.backgroundImageView.bounds.size opaque:YES];
        [self.imageCache setObject:preparedImage forKey:key];
    }
    
    CANCEL_OPERATION_IF_NEEDED(operation);
    
    void (^animationBlock)(void) = ^{
        self.activityIndicatorView.alpha = 0.0;
        self.backgroundImageView.alpha = 1.0;
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.backgroundImageView.image = preparedImage;
        
        if (self.loadSynchronously)
        {
            animationBlock();
        }
        else
        {
            [UIView animateWithDuration:0.2 animations:animationBlock completion:^(BOOL finished) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.activityIndicatorView stopAnimating];
                });
            }];
        }
        
    });
}

#pragma mark - Getters/Setters

- (void)setImage:(UIImage *)image
{
    _image = image;
    
    [self update];
}

- (void)setImageURL:(NSURL *)imageURL
{
    _imageURL = [imageURL copy];
    
    [self update];
}

@end
