//
//  GBASettingsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASettingsViewController.h"

NSString *const GBASettingsDidChangeNotification = @"GBASettingsDidChangeNotification";

@interface GBASettingsViewController ()

@property (weak, nonatomic) IBOutlet UISegmentedControl *frameSkipSegmentedControl;
@property (weak, nonatomic) IBOutlet UISwitch *autoSaveSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *mixAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *vibrateSwitch;

- (IBAction)dismissSettings:(UIBarButtonItem *)barButtonItem;

- (IBAction)changeFrameSkip:(UISegmentedControl *)sender;
- (IBAction)toggleAutoSave:(UISwitch *)sender;
- (IBAction)toggleVibrate:(UISwitch *)sender;
- (IBAction)toggleMixAudio:(UISwitch *)sender;

@end

@implementation GBASettingsViewController

- (id)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
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
    NSDictionary *defaults = @{@"frameSkip": @(-1),
                               @"autoSave": @(1),
                               @"vibrate": @YES};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    
}

- (void)updateControls
{
    NSUInteger selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"frameSkip"];
    
    if ((int)selectedSegmentIndex == -1)
    {
        selectedSegmentIndex = 5;
    }
    
    self.frameSkipSegmentedControl.selectedSegmentIndex = selectedSegmentIndex;
    
    self.autoSaveSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"autoSave"];
    self.mixAudioSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"mixAudio"];
    self.vibrateSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [super numberOfSectionsInTableView:tableView];
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
    
    switch (theme) {
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
    }
    
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
    
    [[NSUserDefaults standardUserDefaults] setInteger:frameSkip forKey:@"frameSkip"];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self];
}

- (IBAction)toggleAutoSave:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"autoSave"];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self];
}

- (IBAction)toggleVibrate:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"vibrate"];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self];
}

- (IBAction)toggleMixAudio:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"mixAudio"];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self];
}

@end








