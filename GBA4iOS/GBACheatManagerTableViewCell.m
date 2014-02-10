//
//  GBACheatManagerTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACheatManagerTableViewCell.h"

@implementation GBACheatManagerTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.showsReorderControl = YES;
        self.detailTextLabel.font = [UIFont boldSystemFontOfSize:self.detailTextLabel.font.pointSize];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (editing)
    {
        self.detailTextLabel.hidden = YES;
    }
    else
    {
        self.detailTextLabel.hidden = NO;
    }
    
    [self layoutIfNeeded];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if ([self.detailTextLabel.text isEqualToString:@""] || [self isEditing])
    {
        return;
    }
    
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
