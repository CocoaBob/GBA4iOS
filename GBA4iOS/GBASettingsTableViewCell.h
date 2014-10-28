//
//  GBASettingsTableViewCell.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/10/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

extern CGFloat GBASettingsTableViewCellDefaultSpacing;

@interface GBASettingsTableViewCell : UITableViewCell

- (void)pinView:(UIView *)view toEdge:(UIRectEdge)rectEdge withSpacing:(CGFloat)spacing;

@end
