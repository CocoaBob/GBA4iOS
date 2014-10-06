//
//  GBAWebBrowserHomepageViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/2/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAWebBrowserHomepageViewController.h"
#import "GBASettingsViewController.h"

@interface GBAWebBrowserHomepageViewController () <UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UITextField *customHomepageTextField;

@end

@implementation GBAWebBrowserHomepageViewController

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"webBrowserHomepageViewController"];
    if (self)
    {
        
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.customHomepageTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsCustomHomepageKey];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Helper Methods -

+ (NSString *)localizedNameForWebBrowserHomepage:(GBAWebBrowserHomepage)webBrowserHomepage
{
    NSString *localizedName = nil;
    
    switch (webBrowserHomepage)
    {
        case GBAWebBrowserHomepageGoogle:
            localizedName = NSLocalizedString(@"Google", @"");
            break;
            
        case GBAWebBrowserHomepageYahoo:
            localizedName = NSLocalizedString(@"Yahoo", @"");
            break;
            
        case GBAWebBrowserHomepageBing:
            localizedName = NSLocalizedString(@"Bing", @"");
            break;
            
        case GBAWebBrowserHomepageGameFAQs:
            localizedName = NSLocalizedString(@"GameFAQs", @"");
            break;
            
        case GBAWebBrowserHomepageSuperCheats:
            localizedName = NSLocalizedString(@"Super Cheats", @"");
            break;
            
        case GBAWebBrowserHomepageCustom:
            localizedName = NSLocalizedString(@"Custom", @"");
            
        default:
            localizedName = NSLocalizedString(@"Custom", @"");
            break;
    }
    
    return localizedName;
}

#pragma mark - UITableViewDataSource -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    GBAWebBrowserHomepage homepage = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsSelectedHomepageKey];
    
    if (homepage != GBAWebBrowserHomepageCustom)
    {
        return 1;
    }
    
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if (indexPath.section != 0)
    {
        return cell;
    }
    
    GBAWebBrowserHomepage homepage = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsSelectedHomepageKey];
    
    if (indexPath.row == homepage || (homepage == GBAWebBrowserHomepageCustom && indexPath.row == [self.tableView numberOfRowsInSection:0] - 1))
    {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 0)
    {
        return;
    }
    
    GBAWebBrowserHomepage homepage = indexPath.row;
    
    if (indexPath.row == [tableView numberOfRowsInSection:0] - 1)
    {
        homepage = GBAWebBrowserHomepageCustom;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:homepage forKey:GBASettingsSelectedHomepageKey];
    
    if ([tableView numberOfSections] != [self numberOfSectionsInTableView:tableView])
    {
        // Apparently reloading, inserting, and deleting sections totally sucks on static table views >__>
        // So here is an alternative animation
        [UIView transitionWithView:self.tableView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self.tableView reloadData];
        } completion:nil];
    }
    else
    {
        [self.tableView reloadData];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsSelectedHomepageKey, @"value": @(homepage)}];
}

#pragma mark - UITextFieldDelegate -

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:GBASettingsCustomHomepageKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsCustomHomepageKey, @"value": textField.text}];
}

@end
