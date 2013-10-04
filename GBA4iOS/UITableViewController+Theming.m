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
            cell.backgroundColor = [UIColor whiteColor];
            cell.textLabel.backgroundColor = [UIColor whiteColor];
            cell.detailTextLabel.backgroundColor = [UIColor whiteColor];
            break;
        }
            
        case GBAThemedTableViewControllerThemeTranslucent:
        {
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.backgroundColor = [UIColor clearColor];
            cell.detailTextLabel.backgroundColor = [UIColor clearColor];
            
            break;
        }
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
