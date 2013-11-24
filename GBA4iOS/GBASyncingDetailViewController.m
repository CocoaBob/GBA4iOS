//
//  GBASyncingDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncingDetailViewController.h"
#import "UIAlertView+RSTAdditions.h"
#import "GBASyncManager.h"

#import <DropboxSDK/DropboxSDK.h>

@interface GBASyncingDetailViewController () <DBRestClientDelegate>

@property (readwrite, strong, nonatomic) GBAROM *rom;
@property (strong, nonatomic) NSDictionary *disabledSyncingROMs;
@property (strong, nonatomic) NSIndexPath *selectedSaveIndexPath;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@property (strong, nonatomic) DBRestClient *restClient;
@property (strong, nonatomic) NSMutableArray *remoteSaves;
@property (strong, nonatomic) NSMutableDictionary *pendingDownloads;
@property (strong, nonatomic) NSMutableDictionary *uploadHistories;

@property (assign, nonatomic) BOOL loadingFiles;
@property (assign, nonatomic) BOOL errorLoadingFiles;

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
    
    if ([self.rom conflicted])
    {
        [self fetchRemoteSaveInfo];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Dropbox Settings

- (void)toggleSyncGameData:(UISwitch *)sender
{
    // Can always turn off, and can turn on if not conflicted
    if (!sender.on || ![self.rom conflicted])
    {
        self.rom.syncingDisabled = !sender.on;
        return;
    }
    
    if (self.selectedSaveIndexPath)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Are you sure?", @"") message:NSLocalizedString(@"Once syncing is enabled, the save file for this game on all your other devices will be overwritten with the one you selected. Please make sure you have selected the correct save file, then tap Enable.", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Enable", @""), nil];
        
        [alert show];
        
        double delayInSeconds = 0.2;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [sender setOn:NO animated:YES];
        });
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Save Selected", @"")
                                                        message:NSLocalizedString(@"The save data for this game is not in sync with Dropbox. Please select the save file you want to sync to your other devices, then try again.\n\nNOTE: This will overwrite the save file for this game on your other devices.", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Dismiss", @"") otherButtonTitles:nil];
        [alert show];
        
        double delayInSeconds = 0.2;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [sender setOn:NO animated:YES];
        });
    }
}

#pragma mark - Remote Status

- (void)fetchRemoteSaveInfo
{
    if (self.restClient == nil)
    {
        self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        self.restClient.delegate = self;
    }
    
    self.errorLoadingFiles = NO;
    
    // Recreate it every time
    self.remoteSaves = [NSMutableArray array];
    self.pendingDownloads = [NSMutableDictionary dictionary];
    self.uploadHistories = [NSMutableDictionary dictionary];
    
    NSString *remotePath = [NSString stringWithFormat:@"/%@/Saves/", self.rom.name];
    
    self.loadingFiles = YES;
    [self.restClient loadMetadata:remotePath];
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata
{
    for (DBMetadata *fileMetadata in metadata.contents)
    {
        [self.remoteSaves addObject:fileMetadata];
    }
    
    self.errorLoadingFiles = NO;
    self.loadingFiles = NO;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self uploadHistoryDirectoryPath] error:nil];
    for (NSString *filename in contents)
    {
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:[[self uploadHistoryDirectoryPath] stringByAppendingPathComponent:filename]];
        [self.uploadHistories setObject:dictionary forKey:[filename stringByDeletingPathExtension]];
    }
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
    
    DLog(@"Remote Saves: %@", self.remoteSaves);
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error
{
    self.errorLoadingFiles = YES;
    self.loadingFiles = NO;
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([self.rom conflicted])
    {
        return 4;
    }
    
    return 1;
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
        numberOfRows = 0;
    }
    else if (section == 2)
    {
        numberOfRows = 1;
    }
    else if (section == 3)
    {
        if (self.loadingFiles || self.errorLoadingFiles)
        {
            return 1;
        }
        else
        {
            numberOfRows = [self.remoteSaves count];
        }
    }
    
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
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:SwitchCellIdentifier];
        cell.textLabel.minimumScaleFactor = 0.5;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.detailTextLabel.minimumScaleFactor = 0.5;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        
        if (indexPath.section == 0)
        {
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.on = !self.rom.syncingDisabled;
            [switchView addTarget:self action:@selector(toggleSyncGameData:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    }
    
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    
    if (indexPath.section == 0)
    {
        cell.textLabel.text = NSLocalizedString(@"Sync Save Data", @"");
    }
    else
    {
        if (indexPath.section == 2)
        {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
            
            NSString *localSavePath = [documentsDirectory stringByAppendingPathComponent:[self.rom.name stringByAppendingPathExtension:@"sav"]];
            
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:localSavePath error:nil];
            
            cell.textLabel.text = [self.dateFormatter stringFromDate:[attributes fileModificationDate]];
        }
        else if (indexPath.section == 3)
        {
            if (self.loadingFiles)
            {
                cell.textLabel.text = NSLocalizedString(@"Loading...", @"");
            }
            else if (self.errorLoadingFiles)
            {
                cell.textLabel.text = NSLocalizedString(@"Error Loading Save Info", @"");
            }
            else
            {
                DBMetadata *metadata = self.remoteSaves[indexPath.row];
                NSString *device = [self deviceNameForMetadata:metadata];
                
                cell.textLabel.text = device;
                cell.detailTextLabel.text = [self.dateFormatter stringFromDate:metadata.lastModifiedDate];
            }
        }
        
        if ([indexPath isEqual:self.selectedSaveIndexPath])
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else
        {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 1)
    {
        return NSLocalizedString(@"Save Data Conflicted", @"");
    }
    else if (section == 2)
    {
        return NSLocalizedString(@"Current", @"");
    }
    else if (section == 3)
    {
        return NSLocalizedString(@"Dropbox", @"");
    }
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    /*if (section == 0)
    {
        return NSLocalizedString(@"If turned off, the save data for this game will not be synced to other devices, regardless of whether Dropbox Sync is turned on or not.", @"");
    }*/
    
    if (section == 1)
    {
        return NSLocalizedString(@"The save data for this game is out of sync with Dropbox. To re-enable syncing, please select the save file you want to use, then toggle the above switch on.", @"");
    }
    
    return nil;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return;
    }
    
    if (indexPath.section == 3 && self.errorLoadingFiles)
    {
        [self fetchRemoteSaveInfo];
        return;
    }
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:self.selectedSaveIndexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    if ([indexPath isEqual:self.selectedSaveIndexPath])
    {
        self.selectedSaveIndexPath = nil;
    }
    else
    {
        self.selectedSaveIndexPath = indexPath;
        
        cell = [tableView cellForRowAtIndexPath:self.selectedSaveIndexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    [cell setSelected:NO animated:YES];
}

#pragma mark - Helper Methods

- (NSString *)dropboxSyncDirectoryPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dropboxDirectory = [libraryDirectory stringByAppendingPathComponent:@"Dropbox Sync"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:dropboxDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return dropboxDirectory;
}

- (NSString *)uploadHistoryDirectoryPath
{
    NSString *directory = [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"Upload History"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}

- (NSString *)deviceNameForMetadata:(DBMetadata *)metadata
{
    __block NSString *deviceName = nil;
    
    NSDictionary *uploadHistories = [self.uploadHistories copy];
    [uploadHistories enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *dictionary, BOOL *stop) {
        NSDictionary *romDictionary = dictionary[self.rom.name];
        
        NSString *remoteRev = romDictionary[metadata.path];
        
        if ([remoteRev isEqualToString:metadata.rev])
        {
            deviceName = key;
            *stop = YES;
        }
    }];
    
    return deviceName;
}

#pragma mark - Getters/Setters

- (DBRestClient *)restClient
{
    if (_restClient == nil)
    {
        _restClient == [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    
    return _restClient;
}

- (NSDateFormatter *)dateFormatter
{
    if (_dateFormatter == nil)
    {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        [_dateFormatter setDateStyle:NSDateFormatterLongStyle];
    }
    
    return _dateFormatter;
}

@end
