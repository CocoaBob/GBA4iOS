//
//  UITableViewController+Theming.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/3/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "UITableViewController+Theming.h"

@implementation UITableViewController (Theming)

- (void)themeTableViewCell:(UITableViewCell *)cell
{
    NSAssert([self conformsToProtocol:@protocol(GBAThemedTableViewController)], @"Table View Controller must conform to the GBAThemedTableViewController protocol to support theming");
    
    GBAThemedTableViewControllerTheme theme = [[self valueForKey:@"theme"] integerValue];
    
    switch (theme)
    {
        case GBAThemedTableViewControllerThemeOpaque:
        {
            cell.textLabel.textColor = [UIColor blackColor];
            cell.detailTextLabel.textColor = [UIColor grayColor];
            cell.backgroundColor = [UIColor whiteColor];
            cell.textLabel.backgroundColor = [UIColor whiteColor];
            cell.detailTextLabel.backgroundColor = [UIColor whiteColor];
            break;
        }
            
        case GBAThemedTableViewControllerThemeTranslucent:
        {
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.detailTextLabel.textColor = [UIColor grayColor];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.backgroundColor = [UIColor clearColor];
            cell.detailTextLabel.backgroundColor = [UIColor clearColor];
            
            self.tableView.sectionIndexBackgroundColor = [UIColor clearColor];
            break;
        }
    }
    
    cell.backgroundView = nil;
    cell.textLabel.font = [UIFont systemFontOfSize:cell.textLabel.font.pointSize];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:cell.detailTextLabel.font.pointSize];
}

- (void)themeHeader:(UITableViewHeaderFooterView *)header
{
    NSAssert([self conformsToProtocol:@protocol(GBAThemedTableViewController)], @"Table View Controller must conform to the GBAThemedTableViewController protocol to support theming");
    
    GBAThemedTableViewControllerTheme theme = [[self valueForKey:@"theme"] integerValue];
    
    switch (theme)
    {
        case GBAThemedTableViewControllerThemeOpaque:
        {
            header.backgroundView = nil;
            
            header.contentView.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];
            header.textLabel.textColor = [UIColor blackColor];
            break;
        }
            
        case GBAThemedTableViewControllerThemeTranslucent:
        {
            UIView *backgroundView = [[UIView alloc] init];
            backgroundView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
            header.backgroundView = backgroundView;
            
            header.contentView.backgroundColor = [UIColor clearColor];
            header.textLabel.textColor = [UIColor whiteColor];
            
            break;
        }
    }
    
    // Important this stays here, or else some properties (such as text color) don't immediately change on iOS 8 (header needs to be dequeued first)
    [header layoutIfNeeded];
    
    // Need to update these *again* after layoutIfNeeded, which in turn needs to come after all the other adjustments. ¯\_(ツ)_/¯
    switch (theme)
    {
        case GBAThemedTableViewControllerThemeOpaque:
            header.textLabel.textColor = [UIColor blackColor];
            break;
            
        case GBAThemedTableViewControllerThemeTranslucent:
            header.textLabel.textColor = [UIColor whiteColor];
            break;
    }
}

- (void)updateTheme
{
    NSAssert([self conformsToProtocol:@protocol(GBAThemedTableViewController)], @"Table View Controller must conform to the GBAThemedTableViewController protocol to support theming");
    
    GBAThemedTableViewControllerTheme theme = [[self valueForKey:@"theme"] integerValue];
    
    switch (theme)
    {
        case GBAThemedTableViewControllerThemeOpaque:
        {
            if (self.tableView.style == UITableViewStyleGrouped)
            {
                self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
            }
            else
            {
                self.tableView.backgroundColor = [UIColor whiteColor];
            }
            
            self.tableView.backgroundView = nil;
            self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
            
            break;
        }
            
        case GBAThemedTableViewControllerThemeTranslucent:
        {
            self.tableView.backgroundColor = [UIColor clearColor];
            
            self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
            
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [UIColor clearColor];
            
            self.tableView.backgroundView = view;
            
            break;
        }
    }
    
    [self.tableView reloadData];
}

@end
