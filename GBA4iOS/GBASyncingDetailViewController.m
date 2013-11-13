//
//  GBASyncingDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncingDetailViewController.h"
#import <DropboxSDK/DropboxSDK.h>

@interface GBASyncingDetailViewController () <DBRestClientDelegate>

@property (readwrite, strong, nonatomic) GBAROM *rom;
@property (strong, nonatomic) NSDictionary *disabledSyncingROMs;
@property (strong, nonatomic) NSIndexPath *selectedSaveIndexPath;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@property (strong, nonatomic) DBRestClient *restClient;
@property (strong, nonatomic) NSMutableArray *remoteSaves;

@property (assign, nonatomic) BOOL loadingMetadata;
@property (assign, nonatomic) BOOL errorLoadingMetadata;

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

#pragma mark - Remote Status

- (void)fetchRemoteSaveInfo
{
    if (self.restClient == nil)
    {
        self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        self.restClient.delegate = self;
    }
    
    // Recreate it every time
    self.remoteSaves = [NSMutableArray array];
    
    NSString *remotePath = [NSString stringWithFormat:@"/%@/Saves/", self.rom.name];
    
    self.loadingMetadata = YES;
    [self.restClient loadMetadata:remotePath];
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata
{
    self.errorLoadingMetadata = NO;
    self.loadingMetadata = NO;
    for (DBMetadata *fileMetadata in metadata.contents)
    {
        NSDictionary *saveInfo = @{@"metadata": fileMetadata, @"device": @"Riley's iPad Mini"};
        [self.remoteSaves addObject:saveInfo];
    }
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error
{
    self.errorLoadingMetadata = YES;
    self.loadingMetadata = NO;
    
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
        if (self.loadingMetadata || self.errorLoadingMetadata)
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
    }
    
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    
    if (indexPath.section == 0)
    {
        cell.textLabel.text = NSLocalizedString(@"Sync Save Data", @"");
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = !self.rom.syncingDisabled;
        [switchView addTarget:self action:@selector(toggleSyncGameData:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
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
            if (self.loadingMetadata)
            {
                cell.textLabel.text = NSLocalizedString(@"Loading...", @"");
            }
            else if (self.errorLoadingMetadata)
            {
                cell.textLabel.text = NSLocalizedString(@"Error Loading Save Info", @"");
            }
            else
            {
                DBMetadata *metadata = self.remoteSaves[indexPath.row][@"metadata"];
                NSString *device = self.remoteSaves[indexPath.row][@"device"];
                
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
    if (section == 0)
    {
        return NSLocalizedString(@"If turned off, save data for this game will not be synced to other devices, regardless of whether Dropbox Sync is turned on or not.", @"");
    }
    else if (section == 1)
    {
        return NSLocalizedString(@"The save data for this game is out of sync with Dropbox. To prevent data loss, GBA4iOS has disabled syncing for this game. To re-enable syncing, please select the save you want to use, then toggle the above switch on. Be careful, the save you select will overwrite the save for this game on your other devices as well.", @"");
    }
    
    return nil;
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
