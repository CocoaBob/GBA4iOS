//
//  GBAControllerSkinPreviewCell.m
//  GBA4iOS
//
//  Created by Yvette Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinPreviewCell.h"

#define CANCEL_OPERATION_IF_NEEDED(operation) if ([operation isCancelled]) { return; }

@interface GBAControllerSkinPreviewCell ()

@property (strong, nonatomic) UIImageView *skinImageView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (strong, nonatomic) NSOperationQueue *operationQueue;

@end

@implementation GBAControllerSkinPreviewCell

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
    self.skinImageView = ({
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height)];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:imageView];
        imageView;
    });
    
    self.operationQueue = ({
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        queue.name = @"com.rileytestut.GBA4iOS.controller_skin_cell";
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

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)prepareForReuse
{
    [self.skinImageView setImage:nil];
}

- (void)update
{
    [self layoutIfNeeded];
    
    [self.operationQueue cancelAllOperations];
    
    if (self.loadAsynchronously)
    {
        [self.activityIndicatorView startAnimating];
        
        NSBlockOperation *blockOperation = [[NSBlockOperation alloc] init];
        
        __weak NSOperation *weakOperation = blockOperation;
        
        [blockOperation addExecutionBlock:^{
            CANCEL_OPERATION_IF_NEEDED(weakOperation);
            
            UIImage *image = [self.controller imageForOrientation:self.orientation];
            
            CANCEL_OPERATION_IF_NEEDED(weakOperation);
            
            NSDictionary *dictionary = [self.controller dictionaryForOrientation:self.orientation];
            
            image = [self imageByResizingImage:image toFitSize:self.contentView.bounds.size];
            
            CANCEL_OPERATION_IF_NEEDED(weakOperation);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.skinImageView.image = image;
                [self.activityIndicatorView stopAnimating];
            });
        }];
        
        [self.operationQueue addOperation:blockOperation];
    }
    else
    {
        UIImage *image = [self.controller imageForOrientation:self.orientation];
        NSDictionary *dictionary = [self.controller dictionaryForOrientation:self.orientation];
        
        image = [self imageByResizingImage:image toFitSize:self.contentView.bounds.size];
        
        self.skinImageView.image = image;
        [self.activityIndicatorView stopAnimating];
    }
}

#pragma mark - Helper Methods

- (UIImage *)imageByResizingImage:(UIImage *)image toFitSize:(CGSize)size
{
    CGSize resizedSize = [self sizeForImage:image toFitSize:size];
    
    UIGraphicsBeginImageContextWithOptions(resizedSize, YES, image.scale);
    
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

@end
