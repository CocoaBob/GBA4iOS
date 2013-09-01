//
//  GBASettingsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASettingsViewController.h"
#import "GBAControllerSkinDetailViewController.h"

NSString *const GBASettingsDidChangeNotification = @"GBASettingsDidChangeNotification";

@interface GBASettingsViewController ()

@property (weak, nonatomic) IBOutlet UISegmentedControl *frameSkipSegmentedControl;
@property (weak, nonatomic) IBOutlet UISwitch *autosaveSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *mixAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *vibrateSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *showFramerateSwitch;

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem;

- (IBAction)changeFrameSkip:(UISegmentedControl *)sender;
- (IBAction)toggleAutoSave:(UISwitch *)sender;
- (IBAction)toggleVibrate:(UISwitch *)sender;
- (IBAction)toggleMixAudio:(UISwitch *)sender;
- (IBAction)toggleShowFramerate:(UISwitch *)sender;

@end

@implementation GBASettingsViewController

- (id)init
{
    NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"GBAResources" ofType:@"bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:resourceBundle];
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
    
    [self setTheme:self.theme];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Settings

+ (void)registerDefaults
{
    NSDictionary *defaults = @{GBASettingsFrameSkipKey: @(-1),
                               GBASettingsAutosaveKey: @(1),
                               GBASettingsVibrateKey: @YES,
                               GBASettingsGBASkinsKey: @{@"portrait": @"Default", @"landscape": @"Default"},
                               GBASettingsGBCSkinsKey: @{@"portrait": @"Default", @"landscape": @"Default"}};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    
}

- (void)updateControls
{
    NSUInteger selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsFrameSkipKey];
    
    if ((int)selectedSegmentIndex == -1)
    {
        selectedSegmentIndex = self.frameSkipSegmentedControl.numberOfSegments - 1;
    }
    
    self.frameSkipSegmentedControl.selectedSegmentIndex = selectedSegmentIndex;
    
    self.autosaveSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAutosaveKey];
    self.mixAudioSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsMixAudioKey];
    self.vibrateSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsVibrateKey];
    self.showFramerateSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsShowFramerateKey];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [super numberOfSectionsInTableView:tableView];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 1)
    {
        // Hide vibration info if not iPhone (no way to detect if hardware supports vibration)
        if (![[UIDevice currentDevice].model hasPrefix:@"iPhone"])
        {
            return nil;
        }
    }
    
    return [super tableView:tableView viewForFooterInSection:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 1)
    {
        // Hide vibration setting if not iPhone (no way to detect if hardware supports vibration)
        if (![[UIDevice currentDevice].model hasPrefix:@"iPhone"])
        {
            return [super tableView:tableView numberOfRowsInSection:section] - 1;
        }
    }
    
    return [super tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    switch (self.theme) {
        case GBAROMTableViewControllerThemeOpaque:
            cell.backgroundColor = [UIColor whiteColor];
            cell.textLabel.textColor = [UIColor blackColor];
            cell.textLabel.backgroundColor = [UIColor whiteColor];
            cell.detailTextLabel.backgroundColor = [UIColor whiteColor];
            break;
            
        case GBAROMTableViewControllerThemeTranslucent: {
            cell.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.detailTextLabel.textColor = [UIColor blackColor];
            cell.textLabel.backgroundColor = [UIColor clearColor];
            cell.detailTextLabel.backgroundColor = [UIColor clearColor];
            break;
        }
    }
    
    return cell;
}

#pragma mark - Theming

- (void)setTheme:(GBAROMTableViewControllerTheme)theme
{
    _theme = theme;
    
    if (![self isViewLoaded])
    {
        return;
    }
    
    /*switch (theme) {
        case GBAROMTableViewControllerThemeTranslucent: {
            self.tableView.backgroundColor = [UIColor clearColor];
            self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
            
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [UIColor clearColor];
            
            self.tableView.backgroundView = view;
            
            //self.tableView.rowHeight = 600;
            
            break;
        }
            
        case GBAROMTableViewControllerThemeOpaque:
            self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
            self.tableView.backgroundView = nil;
            self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
            
            
            break;
    }*/
    
    [self.tableView reloadData];
}

#pragma mark - IBActions

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)changeFrameSkip:(UISegmentedControl *)sender
{
    NSUInteger frameSkip = sender.selectedSegmentIndex;
    
    if (frameSkip == sender.numberOfSegments - 1)
    {
        frameSkip = -1;
    }
    
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

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Controller Skins
    if (indexPath.section == 3)
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
}

@end








