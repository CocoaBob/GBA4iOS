//
//  GBAThemedTableViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBATransparentTableViewHeaderFooterView.h"

typedef NS_ENUM(NSInteger, GBAThemedTableViewControllerTheme)
{
    GBAThemedTableViewControllerThemeOpaque = 0,
    GBAThemedTableViewControllerThemeTranslucent = 1
};

@interface GBAThemedTableViewController : UITableViewController

@property (assign, nonatomic) GBAThemedTableViewControllerTheme theme;

- (instancetype)initWithTheme:(GBAThemedTableViewControllerTheme)theme;

@end
