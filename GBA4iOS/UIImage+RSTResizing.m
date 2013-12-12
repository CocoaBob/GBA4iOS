//
//  UIImage+RSTResizing.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "UIImage+RSTResizing.h"

@implementation UIImage (RSTResizing)

- (UIImage *)imageByResizingToFitSize:(CGSize)size opaque:(BOOL)opaque
{
    CGSize resizedSize = [self sizeForImageToFitSize:size];
        
    UIGraphicsBeginImageContextWithOptions(resizedSize, opaque, [UIScreen mainScreen].scale);
    
    [self drawInRect:CGRectMake(0, 0, resizedSize.width, resizedSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (CGSize)sizeForImageToFitSize:(CGSize)containerSize
{
    CGSize size = CGSizeZero;
    CGSize imageSize = self.size;
    
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
