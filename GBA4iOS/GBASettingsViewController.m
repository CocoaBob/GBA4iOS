//
//  GBASettingsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASettingsViewController.h"
#import "GBAControllerSkinDetailViewController.h"

#import <Dropbox/Dropbox.h>

#define FRAME_SKIP_SECTION 0
#define GENERAL_SECTION 1
#define SAVING_SECTION 2
#define CONTROLLER_SKINS_SECTION 3
#define CONTROLLER_OPACITY_SECTION 4
#define DROPBOX_SYNC_SECTION 5
#define CREDITS_SECTION 6

NSString *const GBASettingsDidChangeNotification = @"GBASettingsDidChangeNotification";
NSString *const GBASettingsDropboxStatusChangedNotification = @"GBASettingsDropboxStatusChangedNotification";

@interface GBASettingsViewController ()

@property (weak, nonatomic) IBOutlet UISegmentedControl *frameSkipSegmentedControl;
@property (weak, nonatomic) IBOutlet UISwitch *autosaveSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *mixAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *vibrateSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *showFramerateSwitch;
@property (weak, nonatomic) IBOutlet UISlider *controllerOpacitySlider;
@property (weak, nonatomic) IBOutlet UILabel *controllerOpacityLabel;
@property (weak, nonatomic) IBOutlet UISwitch *dropboxSyncSwitch;

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem;

- (IBAction)changeFrameSkip:(UISegmentedControl *)sender;
- (IBAction)toggleAutoSave:(UISwitch *)sender;
- (IBAction)toggleVibrate:(UISwitch *)sender;
- (IBAction)toggleMixAudio:(UISwitch *)sender;
- (IBAction)toggleShowFramerate:(UISwitch *)sender;
- (IBAction)changeControllerOpacity:(UISlider *)sender;
- (IBAction)jumpToRoundedOpacityValue:(UISlider *)sender;
- (IBAction)toggleDropboxSync:(UISwitch *)sender;

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
    
    [self updateControls];
    
    [[DBAccountManager sharedManager] addObserver:self block:^(DBAccount *account) {
        if (account && [self.tableView numberOfRowsInSection:DROPBOX_SYNC_SECTION] == 1)
        {
            // Just because the user linked the account does not mean we should turn on Dropbox Sync
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:DROPBOX_SYNC_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
        }
        else if ((account == nil || ![account isLinked]) && [self.tableView numberOfRowsInSection:DROPBOX_SYNC_SECTION] == 2)
        {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsDropboxSyncKey];
            
            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:DROPBOX_SYNC_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
            [self.dropboxSyncSwitch setOn:NO animated:YES];
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[DBAccountManager sharedManager] removeObserver:self];
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
    
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    
    if (account == nil)
    {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsDropboxSyncKey];
    }
    
}

- (void)updateControls
{
    NSUInteger selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsFrameSkipKey];
    
    self.frameSkipSegmentedControl.selectedSegmentIndex = selectedSegmentIndex + 1;
    
    self.autosaveSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAutosaveKey];
    self.mixAudioSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsMixAudioKey];
    self.vibrateSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsVibrateKey];
    self.showFramerateSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsShowFramerateKey];
    self.controllerOpacitySlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
    self.dropboxSyncSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey];
    
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
        DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
        
        if (account == nil)
        {
            return 1;
        }
    }
    
    return [super tableView:tableView numberOfRowsInSection:section];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if (indexPath.section == CREDITS_SECTION && indexPath.row == 2)
    {
        if ([[[[[UIDevice currentDevice] name] lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"iphone"] ||
            [[[[UIDevice currentDevice] name] lowercaseString] hasPrefix:@"david m"])
        {
            cell.textLabel.text = @"Alyssa Testut";
        }
    }
    
    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.textColor = [UIColor blackColor];
    cell.textLabel.backgroundColor = [UIColor whiteColor];
    cell.detailTextLabel.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == DROPBOX_SYNC_SECTION)
    {
        cell.textLabel.frame = ({
            CGRect frame = cell.textLabel.frame;
            frame.origin.x = 15.0f;
            frame.size.width = cell.bounds.size.width - 30.0f;
            frame;
        });
        
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    }
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
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsMixAudioKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsMixAudioKey, @"value": @(sender.on)}];
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

- (IBAction)toggleDropboxSync:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsDropboxSyncKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsDropboxSyncKey, @"value": @(sender.on)}];
    
    if (sender.on && [[DBAccountManager sharedManager] linkedAccount] == nil)
    {
        [self linkDropboxAccount];
    }
}

#pragma mark - Dropbox

- (void)linkDropboxAccount
{
    if ([[DBAccountManager sharedManager] linkedAccount])
    {
        return [[[DBAccountManager sharedManager] linkedAccount] unlink];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedDropboxURLCallback:) name:GBASettingsDropboxStatusChangedNotification object:nil];
    [[DBAccountManager sharedManager] linkFromController:self];
}

- (void)receivedDropboxURLCallback:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GBASettingsDropboxStatusChangedNotification object:nil];
    
    if ([[DBAccountManager sharedManager] linkedAccount] == nil)
    {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsDropboxSyncKey];
        [self.dropboxSyncSwitch setOn:NO animated:YES];
    }
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
        if (indexPath.row == 1)
        {
            [self linkDropboxAccount];
        }
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

@end








