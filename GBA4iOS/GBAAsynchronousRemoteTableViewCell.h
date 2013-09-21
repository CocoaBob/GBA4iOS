//
//  GBAAsynchronousRemoteTableViewCell.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GBAAsynchronousRemoteTableViewCell : UITableViewCell

// Remote URL
@property (strong, nonatomic) NSURL *imageURL;

// Assign image cache so all instances have a common cache
@property (weak, nonatomic) NSCache *imageCache;

// Manually update the cell's contents
- (void)update;

@end
