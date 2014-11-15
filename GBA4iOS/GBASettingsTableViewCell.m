//
//  GBASettingsTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/10/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASettingsTableViewCell.h"

CGFloat GBASettingsTableViewCellDefaultSpacing = -1815;

@interface GBASettingsTableViewCell ()

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *leftInsetConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *rightInsetConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *topInsetConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomInsetConstraint;

@property (assign, nonatomic) CGFloat leftInsetSpacing;
@property (assign, nonatomic) CGFloat rightInsetSpacing;
@property (assign, nonatomic) CGFloat topInsetSpacing;
@property (assign, nonatomic) CGFloat bottomInsetSpacing;

@end

@implementation GBASettingsTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (void)initialize
{
    self.leftInsetSpacing = GBASettingsTableViewCellDefaultSpacing;
    self.rightInsetSpacing = GBASettingsTableViewCellDefaultSpacing;
    self.topInsetSpacing = GBASettingsTableViewCellDefaultSpacing;
    self.bottomInsetSpacing = GBASettingsTableViewCellDefaultSpacing;
}

- (void)layoutSubviews
{
    if ([self.textLabel.text length] == 0)
    {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
    }
    
    [super layoutSubviews];
    
    CGFloat inset = CGRectGetMinX(self.textLabel.frame);
        
    if (self.leftInsetSpacing == GBASettingsTableViewCellDefaultSpacing)
    {
        self.leftInsetConstraint.constant = inset;
    }
    
    if (self.rightInsetSpacing == GBASettingsTableViewCellDefaultSpacing)
    {
        self.rightInsetConstraint.constant = inset;
    }
    
    if (self.topInsetSpacing == GBASettingsTableViewCellDefaultSpacing)
    {
        self.topInsetConstraint.constant = 5;
    }
    
    if (self.bottomInsetSpacing == GBASettingsTableViewCellDefaultSpacing)
    {
        self.bottomInsetConstraint.constant = 5;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
}

- (void)pinView:(UIView *)view toEdge:(UIRectEdge)rectEdge withSpacing:(CGFloat)spacing
{
    if (rectEdge & UIRectEdgeLeft)
    {
        self.leftInsetSpacing = spacing;
        
        [self.contentView removeConstraint:self.leftInsetConstraint];
        
        self.leftInsetConstraint = [NSLayoutConstraint constraintWithItem:view
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self.contentView
                                                                attribute:NSLayoutAttributeLeft
                                                               multiplier:1.0
                                                                 constant:MAX(0, spacing)];
        
        [self.contentView addConstraint:self.leftInsetConstraint];
    }
    
    if (rectEdge & UIRectEdgeRight)
    {
        self.rightInsetSpacing = spacing;
        
        CGFloat visibleSpacing = spacing;
        if (visibleSpacing == GBASettingsTableViewCellDefaultSpacing)
        {
            visibleSpacing = 0;
        }
        
        [self.contentView removeConstraint:self.rightInsetConstraint];
        
        self.rightInsetConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                attribute:NSLayoutAttributeRight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:view
                                                                attribute:NSLayoutAttributeRight
                                                               multiplier:1.0
                                                                 constant:MAX(0, spacing)];
        
        [self.contentView addConstraint:self.rightInsetConstraint];
    }
    
    if (rectEdge & UIRectEdgeTop)
    {
        self.topInsetSpacing = spacing;
        
        CGFloat visibleSpacing = spacing;
        if (visibleSpacing == GBASettingsTableViewCellDefaultSpacing)
        {
            visibleSpacing = 0;
        }
        
        [self.contentView removeConstraint:self.topInsetConstraint];
        
        self.topInsetConstraint = [NSLayoutConstraint constraintWithItem:view
                                                                 attribute:NSLayoutAttributeTop
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.contentView
                                                                 attribute:NSLayoutAttributeTop
                                                                multiplier:1.0
                                                                  constant:MAX(0, spacing)];
        
        [self.contentView addConstraint:self.topInsetConstraint];
    }
    
    if (rectEdge & UIRectEdgeBottom)
    {
        self.bottomInsetSpacing = spacing;
        
        CGFloat visibleSpacing = spacing;
        if (visibleSpacing == GBASettingsTableViewCellDefaultSpacing)
        {
            visibleSpacing = 0;
        }
        
        [self.contentView removeConstraint:self.bottomInsetConstraint];
        
        self.bottomInsetConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                               attribute:NSLayoutAttributeBottom
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:view
                                                               attribute:NSLayoutAttributeBottom
                                                              multiplier:1.0
                                                                constant:MAX(0, spacing)];
        
        [self.contentView addConstraint:self.bottomInsetConstraint];
    }
    
    [self layoutIfNeeded];
}

@end
