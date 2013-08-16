//
//  GBAThemedTableViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAThemedTableViewController.h"

@interface GBAThemedTableViewController ()

@end

@implementation GBAThemedTableViewController

- (instancetype)initWithTheme:(GBAThemedTableViewControllerTheme)theme
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)
    {
        self.theme = theme;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView registerClass:[GBATransparentTableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"Header"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
#warning Incomplete method implementation.
    // Return the number of rows in the section.
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    switch (self.theme) {
        case GBAROMTableViewControllerThemeOpaque:
            cell.backgroundColor = [UIColor whiteColor];
            cell.textLabel.textColor = [UIColor blackColor];
            cell.detailTextLabel.textColor = [UIColor grayColor];
            cell.textLabel.backgroundColor = [UIColor whiteColor];
            cell.detailTextLabel.backgroundColor = [UIColor whiteColor];
            break;
            
        case GBAROMTableViewControllerThemeTranslucent: {
            
            if (self.tableView.style == UITableViewStylePlain)
            {
                cell.backgroundColor = [UIColor clearColor];
                cell.detailTextLabel.textColor = [UIColor whiteColor];
            }
            else
            {
                cell.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
                cell.detailTextLabel.textColor = [UIColor blackColor];
            }
            
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.backgroundColor = [UIColor clearColor];
            cell.detailTextLabel.backgroundColor = [UIColor clearColor];
            break;
        }
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    GBATransparentTableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"Header"];
    headerView.textLabel.text = [super tableView:tableView titleForHeaderInSection:section];
    headerView.theme = self.theme;
    
    return headerView;
}


#pragma mark - Getters/Setters

- (void)setTheme:(GBAThemedTableViewControllerTheme)theme
{
    if (_theme == theme)
    {
        return;
    }
    
    _theme = theme;
    
    switch (theme) {
        case GBAROMTableViewControllerThemeTranslucent: {
            self.tableView.backgroundColor = [UIColor clearColor];
            self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
            
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [UIColor clearColor];
            
            self.tableView.backgroundView = view;
            
            break;
        }
            
        case GBAROMTableViewControllerThemeOpaque:
            
            if (self.tableView.style == UITableViewStylePlain)
            {
                self.tableView.backgroundColor = [UIColor whiteColor];
            }
            else
            {
                self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
            }
            
            self.tableView.backgroundView = nil;
            self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
            
            break;
    }
    
    [self.tableView reloadData];
}

@end
