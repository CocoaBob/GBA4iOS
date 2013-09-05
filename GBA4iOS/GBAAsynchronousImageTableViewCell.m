//
//  GBAAsynchronousImageTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAAsynchronousImageTableViewCell.h"

#define CANCEL_OPERATION_IF_NEEDED(operation) if ([operation isCancelled]) { return; }

@interface GBAAsynchronousImageTableViewCell () <NSURLConnectionDataDelegate>

@property (strong, nonatomic) UIImageView *backgroundImageView;
@property (strong, nonatomic) UILabel *downloadingErrorLabel;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (strong, nonatomic) NSOperationQueue *operationQueue;

@property (strong, nonatomic) NSURLConnection *imageURLConnection;
@property (strong, nonatomic) NSMutableData *imageData;

@end

@implementation GBAAsynchronousImageTableViewCell

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
    
    self.downloadingErrorLabel = ({
        UILabel *label = [[UILabel alloc] init];
        label.text = NSLocalizedString(@"Error Downloading Image", @"");
        [label sizeToFit];
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        label.center = CGPointMake(CGRectGetMidX(self.contentView.bounds), CGRectGetMidY(self.contentView.bounds));
        label.alpha = 0.0;
        [self.contentView addSubview:label];
        label;
    });
}

- (void)prepareForReuse
{
    self.backgroundImageView.image = nil;
    self.backgroundImageView.alpha = 0.0;
    self.imageData = nil;
    self.imageURLConnection = nil;
    self.image = nil;
    self.imageURL = nil;
    self.downloadingErrorLabel.alpha = 0.0;
    self.activityIndicatorView.alpha = 1.0f;
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
    
    [self.activityIndicatorView startAnimating];
    
    [self.operationQueue cancelAllOperations];
    
    if (self.imageURL && ![self.imageURL isFileURL])
    {
        [self loadRemoteImage];
    }
    else
    {
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
    
    UIImage *preparedImage = [self.imageCache objectForKey:self.imageURL];
    
    if (preparedImage == nil)
    {
        preparedImage = [self imageByResizingImage:image toFitSize:self.backgroundImageView.bounds.size];
        [self.imageCache setObject:image forKey:self.imageURL];
    }
    
    CANCEL_OPERATION_IF_NEEDED(operation);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.backgroundImageView.image = preparedImage;
        
        [UIView animateWithDuration:0.2 animations:^{
            self.activityIndicatorView.alpha = 0.0;
            self.downloadingErrorLabel.alpha = 0.0;
            self.backgroundImageView.alpha = 1.0;
        } completion:^(BOOL finished) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicatorView stopAnimating];
            });
        }];
    });
}

#pragma mark - Downloading

- (void)loadRemoteImage
{
    self.imageData = [[NSMutableData alloc] init];
    self.imageURLConnection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:self.imageURL] delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.imageData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    UIImage *image = [UIImage imageWithData:self.imageData];
    [self prepareAndDisplayImage:image withOperation:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicatorView stopAnimating];
    });
    
    [UIView animateWithDuration:0.2 animations:^{
        self.activityIndicatorView.alpha = 0.0;
        self.downloadingErrorLabel.alpha = 1.0;
        self.backgroundImageView.alpha = 0.0;
    } completion:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicatorView stopAnimating];
        });
    }];
}

#pragma mark - Helper Methods

- (UIImage *)imageByResizingImage:(UIImage *)image toFitSize:(CGSize)size
{
    CGSize resizedSize = [self sizeForImage:image toFitSize:size];
    
    // YES for opaque because we want a black background
    UIGraphicsBeginImageContextWithOptions(resizedSize, YES, [UIScreen mainScreen].scale);
    
    [image drawInRect:CGRectMake(0, 0, resizedSize.width, resizedSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (CGSize)sizeForImage:(UIImage *)image toFitSize:(CGSize)containerSize
{
    CGSize size = CGSizeZero;
    CGSize imageSize = image.size;
    
    CGFloat widthScale = containerSize.width/imageSize.width;
    CGFloat heightScale = containerSize.height/imageSize.height;
    
    if (widthScale < heightScale)
    {
        size = CGSizeMake(imageSize.width * widthScale, imageSize.height * widthScale);
    }
    else
    {
        size = CGSizeMake(imageSize.width * heightScale, imageSize.height * heightScale);
    }
    
    return size;
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
