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

#import <DropboxSDK/DropboxSDK.h>

#define FRAME_SKIP_SECTION 0
#define GENERAL_SECTION 1
#define SAVING_SECTION 2
#define CONTROLLER_SKINS_SECTION 3
#define CONTROLLER_OPACITY_SECTION 4
#define DROPBOX_SYNC_SECTION 5
#define CREDITS_SECTION 6

NSString *const GBASettingsDidChangeNotification = @"GBASettingsDidChangeNotification";
NSString *const GBASettingsDropboxStatusChangedNotification = @"GBASettingsDropboxStatusChangedNotification";

@interface GBASettingsViewController () <UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UISegmentedControl *frameSkipSegmentedControl;
@property (weak, nonatomic) IBOutlet UISwitch *autosaveSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *mixAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *vibrateSwitch;
@property (weak, nonatomic) IBOutlet UISlider *controllerOpacitySlider;
@property (weak, nonatomic) IBOutlet UILabel *controllerOpacityLabel;
@property (weak, nonatomic) UILabel *dropboxSyncStatusLabel;

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem;

- (IBAction)changeFrameSkip:(UISegmentedControl *)sender;
- (IBAction)toggleAutoSave:(UISwitch *)sender;
- (IBAction)toggleVibrate:(UISwitch *)sender;
- (IBAction)toggleMixAudio:(UISwitch *)sender;
- (IBAction)changeControllerOpacity:(UISlider *)sender;
- (IBAction)jumpToRoundedOpacityValue:(UISlider *)sender;

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
    NSDictionary *defaults = @{GBASettingsFrameSkipKey: @(-1),
                               GBASettingsAutosaveKey: @(1),
                               GBASettingsVibrateKey: @YES,
                               GBASettingsGBASkinsKey: @{@"portrait": @"GBA/com.GBA4iOS.default", @"landscape": @"GBA/com.GBA4iOS.default"},
                               GBASettingsGBCSkinsKey: @{@"portrait": @"GBC/com.GBA4iOS.default", @"landscape": @"GBC/com.GBA4iOS.default"},
                               GBASettingsControllerOpacityKey: @0.5};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)updateControls
{
    NSUInteger selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsFrameSkipKey];
    
    self.frameSkipSegmentedControl.selectedSegmentIndex = selectedSegmentIndex + 1;
    
    self.autosaveSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAutosaveKey];
    self.mixAudioSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAllowOtherAudioKey];
    self.vibrateSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsVibrateKey];
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
    if (section == GENERAL_SECTION)
    {
        // Hide vibration info if not iPhone (no way to detect if hardware supports vibration)
        if (![[UIDevice currentDevice].model hasPrefix:@"iPhone"])
        {
            return nil;
        }
    }
    
    return [super tableView:tableView titleForFooterInSection:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == GENERAL_SECTION)
    {
        // Hide vibration setting if not iPhone (no way to detect if hardware supports vibration)
        if (![[UIDevice currentDevice].model hasPrefix:@"iPhone"])
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
    
    if (indexPath.section == DROPBOX_SYNC_SECTION)
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
    else if (indexPath.section == CREDITS_SECTION)
    {
        if (indexPath.row == 2)
        {
            if ([[[[[UIDevice currentDevice] name] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"iphone"] ||
                [[[[UIDevice currentDevice] name] lowercaseString] hasPrefix:@"david m"])
            {
                cell.textLabel.text = @"Alyssa Testut";
            }
        }
    }
    
    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.textColor = [UIColor blackColor];
    cell.textLabel.backgroundColor = [UIColor whiteColor];
    cell.detailTextLabel.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == [tableView numberOfSections] - 1)
    {
        UILabel *versionLabel = [[UILabel alloc] init];
        versionLabel.textAlignment = NSTextAlignmentCenter;
        versionLabel.textColor = [UIColor grayColor];
        versionLabel.text = [super tableView:tableView titleForFooterInSection:section];
        return versionLabel;
    }
    
    return [super tableView:tableView viewForFooterInSection:section];
}

#pragma mark - IBActions

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem
{
    if ([self.delegate respondsToSelector:@selector(settingsViewControllerWillDismiss:)])
    {
        [self.delegate settingsViewControllerWillDismiss:self];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
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

- (IBAction)toggleMixAudio:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsAllowOtherAudioKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsAllowOtherAudioKey, @"value": @(sender.on)}];
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


#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
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
    else if (indexPath.section == DROPBOX_SYNC_SECTION)
    {
        GBASyncingOverviewViewController *syncingOverviewViewController = [[GBASyncingOverviewViewController alloc] init];
        [self.navigationController pushViewController:syncingOverviewViewController animated:YES];
    }
    else if (indexPath.section == CREDITS_SECTION)
    {
        [self openLinkForIndexPath:indexPath];
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
    else if (indexPath.row == 4)
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
    }
}


@end








