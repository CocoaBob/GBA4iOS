//
//  RSTFileBrowserTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "RSTFileBrowserTableViewCell.h"

@implementation RSTFileBrowserTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    if (self)
    {
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.detailTextLabel sizeToFit];
        
    CGFloat padding = self.textLabel.frame.origin.x;
    CGFloat paddingMultiplier = 3;
    
    if (self.accessoryType != UITableViewCellAccessoryNone)
    {
        paddingMultiplier = 2;
    }
    
    CGFloat maximumWidth = self.contentView.bounds.size.width - (self.detailTextLabel.bounds.size.width + padding * paddingMultiplier);
    
    self.textLabel.frame = CGRectMake(self.textLabel.frame.origin.x, self.textLabel.frame.origin.y, maximumWidth, self.textLabel.frame.size.height);
    self.detailTextLabel.frame = CGRectMake(CGRectGetMaxX(self.textLabel.frame) + padding, self.detailTextLabel.frame.origin.y, self.detailTextLabel.frame.size.width, self.detailTextLabel.frame.size.height);
}

@end
