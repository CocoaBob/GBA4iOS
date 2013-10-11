//
//  UITableViewController+Theming.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/3/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GBAThemedTableViewControllerTheme)
{
    GBAThemedTableViewControllerThemeOpaque,
    GBAThemedTableViewControllerThemeTranslucent
};

@protocol GBAThemedTableViewController <NSObject>

@property (assign, nonatomic) GBAThemedTableViewControllerTheme theme;

@end

@interface UITableViewController (Theming)

- (void)themeTableViewCell:(UITableViewCell *)cell;
- (void)themeHeader:(UITableViewHeaderFooterView *)header;
- (void)updateTheme;

@end
