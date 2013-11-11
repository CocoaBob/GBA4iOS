//
//  GBASyncingDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncingDetailViewController.h"

@interface GBASyncingDetailViewController ()

@property (readwrite, strong, nonatomic) GBAROM *rom;
@property (strong, nonatomic) NSDictionary *disabledSyncingROMs;

@end

@implementation GBASyncingDetailViewController

- (id)initWithROM:(GBAROM *)rom
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        _rom = rom;
        
        self.title = rom.name;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Dropbox Settings

- (void)toggleSyncGameData:(UISwitch *)sender
{
    self.rom.syncingDisabled = !sender.on;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *SwitchCellIdentifier = @"SwitchCell";
    static NSString *DetailCellIdentifier = @"DetailCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:SwitchCellIdentifier];
    }
    
    if (indexPath.section == 0)
    {
        cell.textLabel.text = NSLocalizedString(@"Sync Save Data", @"");
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = !self.rom.syncingDisabled;
        [switchView addTarget:self action:@selector(toggleSyncGameData:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"If turned off, save data for this ROM will not be synced to other devices, regardless of whether Dropbox Sync is turned on or not.", @"");
    }
    
    return nil;
}

@end
