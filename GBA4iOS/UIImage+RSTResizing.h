//
//  UIImage+RSTResizing.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (RSTResizing)

- (UIImage *)imageByResizingToFitSize:(CGSize)size opaque:(BOOL)opaque;
- (CGSize)sizeForImageToFitSize:(CGSize)containerSize;

@end
