//
//  GBAPushNotificationsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAPushNotificationsViewController.h"
#import "GBASettingsViewController.h"

@interface GBAPushNotificationsViewController ()
@property (strong, nonatomic) IBOutlet UISwitch *eventDistributionsSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *softwareUpdatesSwitch;

@end

@implementation GBAPushNotificationsViewController

- (id)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"pushNotificationsViewController"];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.eventDistributionsSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsEventDistributionPushNotificationsKey];
    self.softwareUpdatesSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsSoftwareUpdatePushNotificationsKey];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1 && section == 2)
    {
        return 0;
    }
    
    return [super tableView:tableView numberOfRowsInSection:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 2)
    {
        return;
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

#pragma mark - Toggling Notifications

- (IBAction)toggleEventDistributionPushNotifications:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsEventDistributionPushNotificationsKey];
}

- (IBAction)toggleSoftwareUpdatePushNotifications:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsSoftwareUpdatePushNotificationsKey];
}


@end
