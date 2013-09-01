//
//  GBAControllerSkinPreviewCell.m
//  GBA4iOS
//
//  Created by Yvette Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinPreviewCell.h"

@interface GBAControllerSkinPreviewCell ()

@property (strong, nonatomic) UIImageView *skinImageView;

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
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

#pragma mark - Getters/Setters

- (void)setController:(GBAController *)controller orientation:(GBAControllerOrientation)orientation
{
    _controller = controller;
    
    UIImage *image = [controller imageForOrientation:orientation];
    NSDictionary *dictionary = [controller dictionaryForOrientation:orientation];
    
    if ([dictionary[@"translucent"] boolValue])
    {
        image = [self imageByAddingBackgroundToImage:image];
    }
    
    self.skinImageView.image = image;
}

#pragma mark - Helper Methods

- (UIImage *)imageByAddingBackgroundToImage:(UIImage *)image
{
    UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
    [[UIColor blackColor] setFill];
    [image drawAtPoint:CGPointMake(0, 0)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
