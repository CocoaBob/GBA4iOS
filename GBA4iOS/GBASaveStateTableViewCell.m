//
//  GBASaveStateTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASaveStateTableViewCell.h"

@interface GBASaveStateTableViewCell ()

@property (strong, nonatomic) UIImageView *lockImageView;

@end

@implementation GBASaveStateTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        UIImage *lockImage = [[UIImage imageNamed:@"Lock"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.lockImageView = [[UIImageView alloc] initWithImage:lockImage];
        self.lockImageView.hidden = NO;
        
        [self.lockImageView sizeToFit];
        
        self.lockImageView.frame = ({
            CGRect frame = self.lockImageView.frame;
            frame.origin.x = self.bounds.size.width - frame.size.width - 15;
            frame.origin.y = 7;
            frame;
        });
        
        [self.contentView addSubview:self.lockImageView];
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
    
    self.textLabel.minimumScaleFactor = 0.75;
    
    if (![self.lockImageView isHidden])
    {
        self.textLabel.frame = ({
            CGRect frame = self.textLabel.frame;
            frame.size.width = self.lockImageView.frame.origin.x - 10;
            frame;
        });
    }
    // No need for else as the call to super automatically resets it
}

- (void)setProtectedSaveState:(BOOL)protectedSaveState
{
    _protectedSaveState = protectedSaveState;
    
    if (_protectedSaveState)
    {
        self.lockImageView.hidden = NO;
    }
    else
    {
        self.lockImageView.hidden = YES;
    }
    
    [self layoutIfNeeded];
}

@end
