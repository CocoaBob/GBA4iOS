//
//  GBASettingsTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/10/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASettingsTableViewCell.h"

@interface GBASettingsTableViewCell ()

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *leftInsetConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *rightInsetConstraint;

@end

@implementation GBASettingsTableViewCell

- (void)awakeFromNib
{
    if ([self.textLabel.text length] == 0)
    {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat inset = CGRectGetMinX(self.textLabel.frame);
    
    self.leftInsetConstraint.constant = inset;
    self.rightInsetConstraint.constant = inset;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
