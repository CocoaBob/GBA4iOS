//
//  GBASyncingOverviewViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/9/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncingOverviewViewController.h"
#import "GBASettingsViewController.h"
#import "GBASyncManager.h"
#import "GBASyncingDetailViewController.h"
#import "RSTFileBrowserTableViewCell.h"

#import <DropboxSDK/DropboxSDK.h>

@interface GBASyncingOverviewViewController () 

@property (weak, nonatomic) UISwitch *dropboxSyncSwitch;

@property (strong, nonatomic) NSArray *gbaROMs;
@property (strong, nonatomic) NSArray *gbcROMs;
@property (strong, nonatomic) NSSet *conflictedROMs;
@property (strong, nonatomic) NSSet *syncingDisabledROMs;

@end

@implementation GBASyncingOverviewViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        self.title = NSLocalizedString(@"Dropbox Sync", @"");
        
        _conflictedROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
        _syncingDisabledROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romConflictedStateDidChange:) name:GBAROMConflictedStateChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romSyncingDisabledStateDidChange:) name:GBAROMSyncingDisabledStateChangedNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:[RSTFileBrowserTableViewCell class] forCellReuseIdentifier:@"DetailCell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SwitchCell"];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Must call this manually before calling super to ensure the row is always deselected
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];
    [super viewWillAppear:animated];
    
    [self updateFiles];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willEnterForeground:(NSNotification *)notification
{
}

#pragma mark - UI

- (void)updateFiles
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSMutableArray *gbaROMs = [NSMutableArray array];
    NSMutableArray *gbcROMs = [NSMutableArray array];
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        NSString *extension = [[filename pathExtension] lowercaseString];
        
        if ([extension isEqualToString:@"gba"])
        {
            GBAROM *rom = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:filename]];
            [gbaROMs addObject:rom];
        }
        else if ([extension isEqualToString:@"gbc"] || [extension isEqualToString:@"gb"])
        {
            GBAROM *rom = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:filename]];
            [gbcROMs addObject:rom];
        }
    }
    
    self.gbaROMs = gbaROMs;
    self.gbcROMs = gbcROMs;
    
    if ([self.tableView numberOfSections] > 2)
    {
        [self.tableView reloadData];
    }
}

#pragma mark - Dropbox

- (IBAction)toggleDropboxSync:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:GBASettingsDropboxSyncKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsDropboxSyncKey, @"value": @(sender.on)}];
    
    if (sender.on)
    {
        if (![[DBSession sharedSession] isLinked])
        {
            [self linkDropboxAccount];
        }
        else
        {
            [[GBASyncManager sharedManager] synchronize];
            
            if ([self.tableView numberOfSections] == 1)
            {
                [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)] withRowAnimation:UITableViewRowAnimationFade];
            }
        }
        
        
    }
    else
    {
        if ([self.tableView numberOfSections] == 4)
        {
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

- (void)linkDropboxAccount
{
    if ([[DBSession sharedSession] isLinked])
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastSyncInfo"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"initialSync"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"newlyConflictedROMs"];
        [[DBSession sharedSession] unlinkAll];
        [self updateDropboxSection];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
        return;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedDropboxURLCallback:) name:GBASettingsDropboxStatusChangedNotification object:nil];
    [[DBSession sharedSession] linkFromController:self];
}

- (void)receivedDropboxURLCallback:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GBASettingsDropboxStatusChangedNotification object:nil];
    
    if (![[DBSession sharedSession] isLinked])
    {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsDropboxSyncKey];
        [self.dropboxSyncSwitch setOn:NO animated:YES];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GBASettingsDropboxSyncKey];
        [self.dropboxSyncSwitch setOn:YES animated:YES];
    }
    
    [self updateDropboxSection];
}

- (void)updateDropboxSection
{
    if ([[DBSession sharedSession] isLinked])
    {
        DLog(@"Performing Initial Sync...");
        [[GBASyncManager sharedManager] synchronize];
    }
    
    if ([[DBSession sharedSession] isLinked] && [self.tableView numberOfSections] == 1)
    {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)] withRowAnimation:UITableViewRowAnimationFade];
    }
    else if (![[DBSession sharedSession] isLinked] && [self.tableView numberOfSections] == 4)
    {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsDropboxSyncKey];
        
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)] withRowAnimation:UITableViewRowAnimationFade];
        [self.dropboxSyncSwitch setOn:NO animated:YES];
    }
}

#pragma mark - ROM Status

- (void)romConflictedStateDidChange:(NSNotification *)notification
{
    self.conflictedROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
    
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
    [self.tableView reloadData];
    [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)romSyncingDisabledStateDidChange:(NSNotification *)notification
{
    self.syncingDisabledROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]];
    
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
    [self.tableView reloadData];
    [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey])
    {
        return 1;
    }
    
    // Return the number of sections.
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 2)
    {
        return NSLocalizedString(@"GBA", @"");
    }
    else if (section == 3)
    {
        return NSLocalizedString(@"GBC", @"");
    }
    
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = 0;
    if (section == 0)
    {
        numberOfRows = 1;
    }
    else if (section == 1)
    {
        numberOfRows = 1;
    }
    else if (section == 2)
    {
        numberOfRows = [self.gbaROMs count];
    }
    else if (section == 3)
    {
        numberOfRows = [self.gbcROMs count];
    }
    // Return the number of rows in the section.
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *SwitchCellIdentifier = @"SwitchCell";
    static NSString *DetailCellIdentifier = @"DetailCell";
    
    NSString *identifier = DetailCellIdentifier;
    
    if (indexPath.section == 0)
    {
        identifier = SwitchCellIdentifier;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.textColor = [UIColor grayColor];
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    if (indexPath.section == 0)
    {
        cell.textLabel.text = NSLocalizedString(@"Dropbox Sync", @"");
        
        UISwitch *switchView = [[UISwitch alloc] init];
        [switchView addTarget:self action:@selector(toggleDropboxSync:) forControlEvents:UIControlEventValueChanged];
        switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey];
        cell.accessoryView = switchView;
        self.dropboxSyncSwitch = switchView;
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else if (indexPath.section == 1)
    {
        cell.textLabel.text = NSLocalizedString(@"Account", @"");
        cell.detailTextLabel.text = NSLocalizedString(@"Riley Testut", @"");
    }
    else
    {
        NSArray *romArray = nil;
        
        if (indexPath.section == 2)
        {
            romArray = self.gbaROMs;
        }
        else if (indexPath.section == 3)
        {
            romArray = self.gbcROMs;
        }
        
        GBAROM *rom = romArray[indexPath.row];
        cell.textLabel.text = [rom name];
                
        // Use NSSet directly for better performance
        if ([self.syncingDisabledROMs containsObject:rom.name])
        {
            cell.detailTextLabel.text = NSLocalizedString(@"Off", @"");
        }
        else
        {
            cell.detailTextLabel.text = NSLocalizedString(@"On", @"");
        }
        
        // Use NSSet directly for better performance
        if ([self.conflictedROMs containsObject:rom.name])
        {
            cell.detailTextLabel.text = NSLocalizedString(@"Conflicted", @"");
            cell.detailTextLabel.textColor = [UIColor redColor];
        }
            
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
    {
        if (indexPath.row == 0)
        {
            [self linkDropboxAccount];
        }
    }
    else if (indexPath.section == 2)
    {
        GBASyncingDetailViewController *syncingDetailViewController = [[GBASyncingDetailViewController alloc] initWithROM:self.gbaROMs[indexPath.row]];
        [self.navigationController pushViewController:syncingDetailViewController animated:YES];
    }
    else if (indexPath.section == 3)
    {
        GBASyncingDetailViewController *syncingDetailViewController = [[GBASyncingDetailViewController alloc] initWithROM:self.gbcROMs[indexPath.row]];
        [self.navigationController pushViewController:syncingDetailViewController animated:YES];
    }
}

#pragma mark - Helper Methods

- (NSString *)dropboxSyncDirectoryPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dropboxDirectory = [libraryDirectory stringByAppendingPathComponent:@"Dropbox Sync"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:dropboxDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return dropboxDirectory;
}

- (NSString *)conflictedROMsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"conflictedROMs.plist"];
}

- (NSString *)syncingDisabledROMsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"syncingDisabledROMs.plist"];
}

@end
