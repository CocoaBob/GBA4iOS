//
//  GBAAsynchronousImageTableViewCell.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GBAAsynchronousLocalImageTableViewCell : UITableViewCell

@property (assign, nonatomic) BOOL loadSynchronously;

@property (strong, nonatomic) UIImage *image;

// Used when there is no imageURL
@property (copy, nonatomic) NSString *cacheKey;

// Storage on disk
@property (strong, nonatomic) NSURL *imageURL;

// Assign image cache so all instances have a common cache
@property (weak, nonatomic) NSCache *imageCache;

// Manually update the cell's contents
- (void)update;

@end
