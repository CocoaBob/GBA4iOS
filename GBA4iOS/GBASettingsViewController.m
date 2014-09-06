//
//  GBASettingsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASettingsViewController.h"
#import "GBAControllerSkinDetailViewController.h"
#import "GBASyncManager.h"
#import "GBASyncingOverviewViewController.h"
#import "GBAExternalControllerCustomizationViewController.h"
#import "GBAExternalController.h"
#import "GBABetaTesterCreditsViewController.h"
#import "GBASoftwareUpdateViewController.h"
#import "GBAPushNotificationsViewController.h"

#import <DropboxSDK/DropboxSDK.h>

#define FRAME_SKIP_SECTION 0
#define LINKING_SECTION 1
#define AUDIO_SECTION 2
#define SAVING_SECTION 3
#define PUSH_NOTIFICATIONS_SECTION 4
#define CONTROLLER_SKINS_SECTION 5
#define CONTROLLER_OPACITY_SECTION 6
#define VIBRATION_SECTION 7
#define EXTERNAL_CONTROLLER_SECTION 8
#define AIRPLAY_SECTION 9
#define DROPBOX_SYNC_SECTION 10
#define SOFTWARE_UPDATE_SECTION 11
#define CREDITS_SECTION 12

NSString *const GBASettingsDidChangeNotification = @"GBASettingsDidChangeNotification";
NSString *const GBASettingsDropboxStatusChangedNotification = @"GBASettingsDropboxStatusChangedNotification";

@interface GBASettingsViewController () <UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UISegmentedControl *frameSkipSegmentedControl;
@property (weak, nonatomic) IBOutlet UISwitch *autosaveSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *preferExternalAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *vibrateSwitch;
@property (weak, nonatomic) IBOutlet UISlider *controllerOpacitySlider;
@property (weak, nonatomic) IBOutlet UILabel *controllerOpacityLabel;
@property (weak, nonatomic) UILabel *dropboxSyncStatusLabel;
@property (weak, nonatomic) IBOutlet UISwitch *airplaySwitch;
@property (weak, nonatomic) UILabel *pushNotificationsEnabledLabel;

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem;

- (IBAction)changeFrameSkip:(UISegmentedControl *)sender;
- (IBAction)toggleAutoSave:(UISwitch *)sender;
- (IBAction)toggleVibrate:(UISwitch *)sender;
- (IBAction)togglePreferExternalAudio:(UISwitch *)sender;
- (IBAction)changeControllerOpacity:(UISlider *)sender;
- (IBAction)jumpToRoundedOpacityValue:(UISlider *)sender;
- (IBAction)toggleAirPlay:(UISwitch *)sender;

@end

@implementation GBASettingsViewController

- (id)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"settingsViewController"];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.delegate = self;
    
    [self updateControls];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    // Must call this manually before calling super to ensure the row is always deselected
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];
    [super viewWillAppear:animated];
}

- (void)dealloc
{
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

#pragma mark - Settings

+ (void)registerDefaults
{
    NSString *gbaDefaultString = [NSString stringWithFormat:@"GBA/%@", GBADefaultSkinIdentifier];
    NSString *gbcDefaultString = [NSString stringWithFormat:@"GBC/%@", GBADefaultSkinIdentifier];
    
    NSDictionary *defaults = @{GBASettingsFrameSkipKey: @(-1),
                               GBASettingsAutosaveKey: @(1),
                               GBASettingsVibrateKey: @YES,
                               GBASettingsGBASkinsKey: @{@"portrait": gbaDefaultString, @"landscape": gbaDefaultString},
                               GBASettingsGBCSkinsKey: @{@"portrait": gbcDefaultString, @"landscape": gbcDefaultString},
                               GBASettingsControllerOpacityKey: @0.5,
                               GBASettingsAirPlayEnabled: @YES,
                               GBASettingsEventDistributionPushNotifications: @YES,
                               GBASettingsSoftwareUpdatePushNotifications: @YES};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    
    [GBAExternalController registerControllerDefaults];
}

- (void)updateControls
{
    NSUInteger selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsFrameSkipKey];
    
    self.frameSkipSegmentedControl.selectedSegmentIndex = selectedSegmentIndex + 1;
    
    self.autosaveSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAutosaveKey];
    self.preferExternalAudioSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsPreferExternalAudioKey];
    self.vibrateSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsVibrateKey];
    self.airplaySwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAirPlayEnabled];
    self.controllerOpacitySlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
    
    NSString *percentage = [NSString stringWithFormat:@"%.f", self.controllerOpacitySlider.value * 100];
    percentage = [percentage stringByAppendingString:@"%"];
    
    self.controllerOpacityLabel.text = percentage;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [super numberOfSectionsInTableView:tableView];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == VIBRATION_SECTION)
    {
        if (![self deviceSupportsVibration])
        {
            return nil;
        }
    }
    else if (section == [tableView numberOfSections] - 1)
    {
        NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey];
        return [NSString stringWithFormat:@"GBA4iOS %@", bundleVersion];
    }
    
    return [super tableView:tableView titleForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == VIBRATION_SECTION)
    {
        if (![self deviceSupportsVibration])
        {
            return 1;
        }
    }
    
    return [super tableView:tableView heightForHeaderInSection:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == VIBRATION_SECTION)
    {
        if (![self deviceSupportsVibration])
        {
            return [super tableView:tableView numberOfRowsInSection:section] - 1;
        }
    }
    else if (section == DROPBOX_SYNC_SECTION)
    {
        if (![[DBSession sharedSession] isLinked] || ![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey])
        {
            return 1;
        }
    }
    
    return [super tableView:tableView numberOfRowsInSection:section];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if (indexPath.section == PUSH_NOTIFICATIONS_SECTION)
    {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsEventDistributionPushNotifications] || [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsSoftwareUpdatePushNotifications])
        {
            cell.detailTextLabel.text = NSLocalizedString(@"On", @"");
        }
        else
        {
            cell.detailTextLabel.text = NSLocalizedString(@"Off", @"");
        }
        
        self.pushNotificationsEnabledLabel = cell.detailTextLabel;
        cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    }
    else if (indexPath.section == DROPBOX_SYNC_SECTION)
    {
        if (indexPath.row == 0)
        {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey])
            {
                cell.detailTextLabel.text = NSLocalizedString(@"On", @"");
            }
            else
            {
                cell.detailTextLabel.text = NSLocalizedString(@"Off", @"");
            }
            
            self.dropboxSyncStatusLabel = cell.detailTextLabel;
            
            // iOS 7 bug: background turns white when returning to this view from the syncing overview view
            cell.detailTextLabel.backgroundColor = [UIColor clearColor];
        }
    }
    
    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.textColor = [UIColor blackColor];
    cell.textLabel.backgroundColor = [UIColor whiteColor];
    cell.detailTextLabel.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == VIBRATION_SECTION)
    {
        if (![self deviceSupportsVibration])
        {
            return nil;
        }
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == VIBRATION_SECTION)
    {
        if (![self deviceSupportsVibration])
        {
            return 1;
        }
    }
    
    return UITableViewAutomaticDimension;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == [tableView numberOfSections] - 1)
    {
        UILabel *versionLabel = [[UILabel alloc] init];
        versionLabel.textAlignment = NSTextAlignmentCenter;
        versionLabel.textColor = [UIColor grayColor];
        versionLabel.text = [self tableView:tableView titleForFooterInSection:section];
        return versionLabel;
    }
    
    return [super tableView:tableView viewForFooterInSection:section];
}

#pragma mark - IBActions

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if ([self.delegate respondsToSelector:@selector(settingsViewControllerWillDismiss:)])
    {
        [self.delegate settingsViewControllerWillDismiss:self];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissExternalControllerCustomizationViewController:(UIBarButtonItem *)barButtonItem
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)changeFrameSkip:(UISegmentedControl *)sender
{
    NSUInteger frameSkip = sender.selectedSegmentIndex - 1; // -1 is auto, so this works
    [[NSUserDefaults standardUserDefaults] setInteger:frameSkip forKey:GBASettingsFrameSkipKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsFrameSkipKey, @"value": @(frameSkip)}];
}

- (IBAction)toggleAutoSave:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsAutosaveKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsAutosaveKey, @"value": @(sender.on)}];
}

- (IBAction)toggleVibrate:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsVibrateKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsVibrateKey, @"value": @(sender.on)}];
}

- (IBAction)togglePreferExternalAudio:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsPreferExternalAudioKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsPreferExternalAudioKey, @"value": @(sender.on)}];
}

- (IBAction)toggleShowFramerate:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsShowFramerateKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsShowFramerateKey, @"value": @(sender.on)}];
}

- (IBAction)changeControllerOpacity:(UISlider *)sender
{
    CGFloat roundedValue = roundf(sender.value / 0.05) * 0.05;
    NSString *percentage = [NSString stringWithFormat:@"%.f", roundedValue * 100];
    percentage = [percentage stringByAppendingString:@"%"];
    
    self.controllerOpacityLabel.text = percentage;
    
    [[NSUserDefaults standardUserDefaults] setFloat:roundedValue forKey:GBASettingsControllerOpacityKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsControllerOpacityKey, @"value": @(roundedValue)}];
}

- (IBAction)jumpToRoundedOpacityValue:(UISlider *)sender
{
    CGFloat roundedValue = roundf(sender.value / 0.05) * 0.05;
    sender.value = roundedValue;
}

- (IBAction)toggleAirPlay:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsAirPlayEnabled];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsAirPlayEnabled, @"value": @(sender.on)}];
}


#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PUSH_NOTIFICATIONS_SECTION)
    {
        GBAPushNotificationsViewController *pushNotificationsViewController = [GBAPushNotificationsViewController new];
        [self.navigationController pushViewController:pushNotificationsViewController animated:YES];
    }
    if (indexPath.section == CONTROLLER_SKINS_SECTION)
    {
        GBAControllerSkinDetailViewController *controllerSkinDetailViewController = [[GBAControllerSkinDetailViewController alloc] init];
        
        if (indexPath.row == 0)
        {
            controllerSkinDetailViewController.controllerSkinType = GBAControllerSkinTypeGBA;
        }
        else
        {
            controllerSkinDetailViewController.controllerSkinType = GBAControllerSkinTypeGBC;
        }
        
        [self.navigationController pushViewController:controllerSkinDetailViewController animated:YES];
    }
    else if (indexPath.section == EXTERNAL_CONTROLLER_SECTION)
    {
        GBAExternalControllerCustomizationViewController *externalControllerCustomizationViewController = [[GBAExternalControllerCustomizationViewController alloc] init];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            [self.navigationController pushViewController:externalControllerCustomizationViewController animated:YES];
        }
        else
        {
            UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissExternalControllerCustomizationViewController:)];
            externalControllerCustomizationViewController.navigationItem.rightBarButtonItem = doneButton;
            
            UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(externalControllerCustomizationViewController);
            navigationController.delegate = self;
            [self presentViewController:navigationController animated:YES completion:nil];
        }
        
    }
    else if (indexPath.section == DROPBOX_SYNC_SECTION)
    {
        GBASyncingOverviewViewController *syncingOverviewViewController = [[GBASyncingOverviewViewController alloc] init];
        [self.navigationController pushViewController:syncingOverviewViewController animated:YES];
    }
    else if (indexPath.section == SOFTWARE_UPDATE_SECTION)
    {
        GBASoftwareUpdateViewController *softwareUpdateViewController = [[GBASoftwareUpdateViewController alloc] init];
        [self.navigationController pushViewController:softwareUpdateViewController animated:YES];
    }
    else if (indexPath.section == CREDITS_SECTION)
    {
        if (indexPath.row == [tableView numberOfRowsInSection:indexPath.section] - 1)
        {
            GBABetaTesterCreditsViewController *betaTesterCreditsViewController = [[GBABetaTesterCreditsViewController alloc] init];
            [self.navigationController pushViewController:betaTesterCreditsViewController animated:YES];
        }
        else
        {
            [self openLinkForIndexPath:indexPath];
        }
    }
}

#pragma mark - Credits

- (void)openLinkForIndexPath:(NSIndexPath *)indexPath
{
    NSString *username = @"";
    
    if (indexPath.row == 0)
    {
        username = @"rileytestut";
    }
    else if (indexPath.row == 1)
    {
        username = @"pau1thor";
    }
    else if (indexPath.row == 2)
    {
        username = @"alyssasurowiec";
    }
    else if (indexPath.row == 3)
    {
        username = @"rakashazi";
    }
    else if (indexPath.row == 4)
    {
        username = @"zodttd";
    }
    else if (indexPath.row == 5)
    {
        username = @"mrjuanfernandez";
    }
    
    [self openTwitterProfileForUsername:username];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openTwitterProfileForUsername:(NSString *)username
{
    NSString *scheme = @"";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot://"]]) // Tweetbot
    {
        scheme = [NSString stringWithFormat:@"tweetbot:///user_profile/%@", username];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitterrific://"]]) // Twitterrific
    {
        scheme = [NSString stringWithFormat:@"twitterrific:///profile?screen_name=%@", username];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) // Twitter
    {
        scheme = [NSString stringWithFormat:@"twitter://user?screen_name=%@", username];
    }
    else // Twitter website
    {
        scheme = [NSString stringWithFormat:@"http://twitter.com/%@", username];
    }
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:scheme]];
}

- (BOOL)deviceSupportsVibration
{
    // No way to detect if hardware supports vibration, so we assume if it's not an iPhone, it doesn't have a vibration motor
    return [[UIDevice currentDevice].model hasPrefix:@"iPhone"];
}

#pragma mark - UINavigationController Delegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == self)
    {
        // Use a reference to the label because reloading the section or row causes graphical glitches under iOS 7, and also removes the highlighted state when using interactive back gesture
        if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey])
        {
            self.dropboxSyncStatusLabel.text = NSLocalizedString(@"On", @"");
        }
        else
        {
            self.dropboxSyncStatusLabel.text = NSLocalizedString(@"Off", @"");
        }
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsEventDistributionPushNotifications] || [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsSoftwareUpdatePushNotifications])
        {
            self.pushNotificationsEnabledLabel.text = NSLocalizedString(@"On", @"");
        }
        else
        {
            self.pushNotificationsEnabledLabel.text = NSLocalizedString(@"Off", @"");
        }
    }
}


- (NSUInteger)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController
{
    return [[navigationController topViewController] supportedInterfaceOrientations];
}


@end








