//
//  GBAAsynchronousImageTableViewCell.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GBAAsynchronousImageTableViewCell : UITableViewCell

// Useful for when you want to display a screen with local images for the first time; you'll wait a few extra milliseconds for the image to load.
// Only supported for local images, because that's all I need for right now.
@property (assign, nonatomic) BOOL loadSynchronously;

// In-memory image
@property (strong, nonatomic) UIImage *image;

// Local or remote image URL
@property (copy, nonatomic) NSURL *imageURL;

// Assign image cache so all instances have a common cache
@property (assign, nonatomic) NSCache *imageCache;

// Manually update the cell's contents
- (void)update;

@end
