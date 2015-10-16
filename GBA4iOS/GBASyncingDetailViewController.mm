//
//  GBASyncingDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncingDetailViewController.h"
#import "UIAlertView+RSTAdditions.h"
#import "GBASyncManager_Private.h"

#import "GBAEmulatorCore.h"

#import <DropboxSDK/DropboxSDK.h>
#import "SSZipArchive.h"

NSString * const GBAShouldRestartCurrentGameNotification = @"GBAShouldRestartCurrentGameNotification";

@interface GBASyncingDetailViewController () <DBRestClientDelegate>

@property (readwrite, strong, nonatomic) GBAROM *rom;
@property (strong, nonatomic) NSDictionary *disabledSyncingROMs;
@property (strong, nonatomic) NSIndexPath *selectedSaveIndexPath;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) UISwitch *syncingEnabledSwitch;

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
    
    if (self.showDoneButton)
    {
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSyncingDetailViewController:)];
        self.navigationItem.rightBarButtonItem = doneButton;
    }
    
    self.syncingEnabledSwitch = ({
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = !self.rom.syncingDisabled;
        switchView.layer.allowsGroupOpacity = YES;
        [switchView addTarget:self action:@selector(toggleSyncGameData:) forControlEvents:UIControlEventValueChanged];
        switchView;
    });
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romConflictedStateDidChange:) name:GBAROMConflictedStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedDeviceUploadHistory:) name:GBAUpdatedDeviceUploadHistoryNotification object:nil];
    
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
    // If ROM isn't conflicted, this is easy.
    if (![self.rom conflicted])
    {
        self.rom.syncingDisabled = !sender.on;
        
        if ([sender isOn])
        {
            [[GBASyncManager sharedManager] synchronize];
        }
        
        return;
    }
    
    // If it is conflicted, we get to handle it yay
    
    // Always allow turning off syncing
    if (![sender isOn])
    {
        self.rom.syncingDisabled = NO;
        return;
    }
    
    if (!self.selectedSaveIndexPath)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Save Selected", @"")
                                                        message:NSLocalizedString(@"The save data for this game is not in sync with Dropbox. Please select the save file you want to sync to your other devices, then try again.\n\nNOTE: This will overwrite the save file for this game on your other devices.", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Dismiss", @"") otherButtonTitles:nil];
        [alert show];
        
        double delayInSeconds = 0.2;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [sender setOn:NO animated:YES];
        });
        
        return;
    }
    
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Are you sure?", @"")
                                                    message:NSLocalizedString(@"Once syncing is enabled, the save file for this game on all your other devices will be overwritten with the one you selected. Please make sure you have selected the correct save file, then tap Enable.", @"")
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                          otherButtonTitles:NSLocalizedString(@"Enable", @""), nil];
    
    [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            [sender setOn:NO animated:YES];
        }
        else if (buttonIndex == 1)
        {
            [self syncWithDropbox];
        }
    }];
}

- (void)syncWithDropbox
{
    // If metadata is nil, but we've loaded the files and there aren't any, we'll allow the file to be uploaded without it
    if (/*metadata ||*/ (self.loadingFiles || self.errorLoadingFiles) || (self.remoteSaves.count == 0 && self.selectedSaveIndexPath.section == 3) || self.selectedSaveIndexPath.section == 0 || self.selectedSaveIndexPath.section == 1)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error communicating with Dropbox", @"")
                                                        message:NSLocalizedString(@"Please make sure you are connected to the internet and try again.", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                                              otherButtonTitles:nil];
        [alert show];
        
        [self.syncingEnabledSwitch setOn:NO animated:YES];
        return;
    }
    
    [self.rom setConflicted:NO];
    [self.rom setSyncingDisabled:NO];
    
    GBASyncCompletionBlock completionBlock = ^(NSString *localPath, DBMetadata *metadata, NSError *error)
    {
        // Give time for the completion alert to appear
        double delayInSeconds = 0.8;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [[GBASyncManager sharedManager] synchronize];
        });
        
    };
    
    BOOL romUsesGBCRTC = [self.rom usesGBCRTC];
    
    NSString *localPath = nil;
    
    if (romUsesGBCRTC)
    {
        if (self.selectedSaveIndexPath.section == 2)
        {
            localPath = [GBASyncManager zippedLocalPathForUploadingSaveFileForROM:self.rom];
        }
        else
        {
            localPath = [GBASyncManager zippedLocalPathForDownloadingSaveFileForROM:self.rom];
        }
    }
    else
    {
        localPath = self.rom.saveFileFilepath;
    }
    
    NSString *saveFileDropboxPath = [self saveFileDropboxPathForROM:self.rom];
    
    if (self.selectedSaveIndexPath.section == 2) // Selected Local Save
    {
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.rom.saveFileFilepath isDirectory:nil])
        {
            // Create an empty save file, since dropbox sync does not sync deletions of save files (which is intentional as a safety precaution)
            [@"" writeToFile:self.rom.saveFileFilepath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        
        if (romUsesGBCRTC)
        {
            if (![[NSFileManager defaultManager] fileExistsAtPath:self.rom.rtcFileFilepath isDirectory:nil])
            {
                // Create an empty save file, since dropbox sync does not sync deletions of .rtcsav files (which is intentional as a safety precaution)
                [@"" writeToFile:self.rom.rtcFileFilepath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
            
            // Below code is same as in -[GBASyncMultipleFilesOperation uploadFiles]
            
            // Make sure no previous files remain there
            [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
            
            [SSZipArchive createZipFileAtPath:localPath withFilesAtPaths:@[self.rom.saveFileFilepath, self.rom.rtcFileFilepath]];
        }
        
        DBMetadata *metadata = [self dropboxMetadataForROM:self.rom];
        
        if (metadata)
        {
            // Use metadata in case upload fails, and user uploads another save before this has a chance to re-upload.
            [[GBASyncManager sharedManager] uploadFileAtPath:localPath withMetadata:metadata completionBlock:completionBlock];
        }
        else
        {
            [[GBASyncManager sharedManager] uploadFileAtPath:localPath toDropboxPath:saveFileDropboxPath completionBlock:completionBlock];
        }
        
        // Delete all conflicted files from Dropbox, leaving only the uploaded file (with correct dropbox filename)
        NSArray *remoteSaves = [self.remoteSaves copy];
        for (DBMetadata *metadata in remoteSaves)
        {
            if ([metadata.path isEqualToString:saveFileDropboxPath])
            {
                continue;
            }
            
            [[GBASyncManager sharedManager] deleteFileAtDropboxPath:metadata.path completionBlock:nil];
        }
        
        return;
    }
    
    DBMetadata *metadata = self.remoteSaves[self.selectedSaveIndexPath.row];
        
    // Selected Dropbox Save
    [[GBASyncManager sharedManager] downloadFileToPath:localPath withMetadata:metadata completionBlock:^(NSString *localPath, DBMetadata *newMetadata, NSError *error) {
        if (error)
        {
            [self.rom setConflicted:YES];
            [self.rom setSyncingDisabled:YES];
            
            [self.syncingEnabledSwitch setOn:NO animated:YES];
        }
        else
        {
            DLog(@"Successfully downloaded save for ROM: %@", self.rom.name);
            
            if ([[[GBAEmulatorCore sharedCore] rom] isEqual:self.rom])
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:GBAShouldRestartCurrentGameNotification object:nil];
            }
        }
        
        DBMetadata *preferredMetadata = [self dropboxMetadataForROM:self.rom];
        
        // Delete all conflicted files from Dropbox, leaving only the uploaded file (with correct dropbox filename)
        NSArray *remoteSaves = [self.remoteSaves copy];
        for (DBMetadata *remoteMetadata in remoteSaves)
        {
            if ([remoteMetadata.path isEqualToString:preferredMetadata.path])
            {
                continue;
            }
            
            [[GBASyncManager sharedManager] deleteFileAtDropboxPath:remoteMetadata.path completionBlock:nil];
        }
        
        if (![metadata.path isEqualToString:saveFileDropboxPath])
        {
            // We upload instead of move it since we can't guarantee the deletions will succeed before attempting to move
            // Have to upload with metadata, or else it'll remain conflicted
            [[GBASyncManager sharedManager] uploadFileAtPath:self.rom.saveFileFilepath withMetadata:preferredMetadata completionBlock:completionBlock];
        }
        else
        {
            if (completionBlock)
            {
                completionBlock(localPath, newMetadata, error);
            }
        }
        
    }];
}

#pragma mark - Remote Status

- (void)romConflictedStateDidChange:(NSNotification *)notification
{
    rst_dispatch_sync_on_main_thread(^{
        if (![self.rom isEqual:notification.object])
        {
            return;
        }
        
        if ([self.rom conflicted] && [self.tableView numberOfSections] == 1)
        {
            [self fetchRemoteSaveInfo];
            [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)] withRowAnimation:UITableViewRowAnimationFade];
        }
        else if (![self.rom conflicted] && [self.tableView numberOfSections] > 1)
        {
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)] withRowAnimation:UITableViewRowAnimationFade];
        }
        
        [self.syncingEnabledSwitch setOn:!self.rom.conflicted animated:YES];
    });
}

- (void)updatedDeviceUploadHistory:(NSString *)notification
{
    rst_dispatch_sync_on_main_thread(^{
        [self reloadUploadHistories];
        
        // Race condition crash
        if ([self.tableView numberOfSections] >= 2)
        {
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
        }
        else
        {
            [self.tableView reloadData];
        }
    });
}

- (void)reloadUploadHistories
{
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self uploadHistoryDirectoryPath] error:nil];
    for (NSString *filename in contents)
    {        
        if (![[filename pathExtension] isEqualToString:@"plist"])
        {
            continue;
        }
        
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:[[self uploadHistoryDirectoryPath] stringByAppendingPathComponent:filename]];
        [self.uploadHistories setObject:dictionary forKey:[filename stringByDeletingPathExtension]];
    }
}

#pragma mark - Fetch Metadata

- (void)fetchRemoteSaveInfo
{
    self.syncingEnabledSwitch.enabled = NO;
    
    self.errorLoadingFiles = NO;
    
    // Recreate it every time
    self.remoteSaves = [NSMutableArray array];
    self.pendingDownloads = [NSMutableDictionary dictionary];
    self.uploadHistories = [NSMutableDictionary dictionary];
    
    NSString *remotePath = [NSString stringWithFormat:@"/%@/Saves/", self.rom.uniqueName];
    
    self.loadingFiles = YES;
    
    if ([self.tableView numberOfSections] >= 2)
    {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
    }
    /* else
    {
        [self.tableView reloadData];
    }*/
    // Don't reload data, leads to rare race condition if ROM becomes conflicted
    
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
    
    [self reloadUploadHistories];
    
    self.syncingEnabledSwitch.enabled = YES;
    
    if ([self.tableView numberOfSections] >= 2)
    {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView reloadData];
    }
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error
{
    if ([error code] == 404)
    {
        [self restClient:client loadedMetadata:nil];
        
        return;
    }
    
    self.errorLoadingFiles = YES;
    self.loadingFiles = NO;
    
    self.syncingEnabledSwitch.enabled = NO;
    
    if (_selectedSaveIndexPath.section == 3)
    {
        _selectedSaveIndexPath = nil;
    }
    
    if ([self.tableView numberOfSections] >= 2)
    {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView reloadData];
    }
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
            cell.accessoryView = self.syncingEnabledSwitch;
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
            
            if (attributes)
            {
                cell.textLabel.text = [self.dateFormatter stringFromDate:[attributes fileModificationDate]];
            }
            else
            {
                cell.textLabel.text = NSLocalizedString(@"No local save file", @"");
            }
            
        }
        else if (indexPath.section == 3)
        {
            if (self.loadingFiles)
            {
                cell.textLabel.text = NSLocalizedString(@"Loading...", @"");
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            else if (self.errorLoadingFiles)
            {
                cell.textLabel.text = NSLocalizedString(@"Error Loading Save Info", @"");
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
            }
            else
            {
                DBMetadata *metadata = self.remoteSaves[indexPath.row];
                NSString *device = [self deviceNameForMetadata:metadata];
                NSString *dateString = [self.dateFormatter stringFromDate:metadata.lastModifiedDate];
                
                if (device)
                {
                    cell.textLabel.text = device;
                    cell.detailTextLabel.text = dateString;
                }
                else
                {
                    cell.textLabel.text = dateString;
                }
                
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
                
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
        // can't call [self.tableView numberOfRowsInSection:] as that leads to recursive lock
        if ([self tableView:self.tableView numberOfRowsInSection:3] > 0)
        {
            return NSLocalizedString(@"Dropbox", @"");
        }
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
        return NSLocalizedString(@"The save data for this game is not in sync with Dropbox. If you want to re-enable syncing, please select the save file you want to use, then toggle the above switch on.", @"");
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
    
    if (indexPath.section == 3 && self.loadingFiles)
    {
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
    
    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
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
        NSDictionary *romDictionary = dictionary[self.rom.uniqueName];
        
        NSString *remoteRev = romDictionary[metadata.path];
                
        if ([remoteRev isEqualToString:metadata.rev])
        {
            deviceName = key;
            *stop = YES;
        }
    }];
    
    return deviceName;
}

- (DBMetadata *)dropboxMetadataForROM:(GBAROM *)rom
{
    NSArray *remoteSaves = [self.remoteSaves copy];
    
    NSString *supportedExtension = nil;
    
    if ([rom usesGBCRTC])
    {
        supportedExtension = @"rtcsav";
    }
    else
    {
        supportedExtension = @"sav";
    }
    
    for (DBMetadata *metadata in remoteSaves)
    {
        if ([metadata.filename isEqualToString:[rom.uniqueName stringByAppendingPathExtension:supportedExtension]])
        {
            return metadata;
        }
    }
    
    return nil;
}

- (NSString *)saveFileDropboxPathForROM:(GBAROM *)rom
{
    NSString *uniqueName = rom.uniqueName;
    
    NSString *dropboxPath = nil;
    
    if ([rom usesGBCRTC])
    {
        dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@.rtcsav", uniqueName, uniqueName];
    }
    else
    {
        dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@.sav", uniqueName, uniqueName];
    }
    
    return dropboxPath;
}

#pragma mark - Dismissal

- (void)dismissSyncingDetailViewController:(UIBarButtonItem *)button
{
    if ([self.rom syncingDisabled])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to keep syncing disabled?", @"") message:NSLocalizedString(@"If syncing remains disabled, data for this game will not be updated on your other devices.", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Keep Disabled", @""), nil];
        
        [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 1)
            {
                if ([self.delegate respondsToSelector:@selector(syncingDetailViewControllerWillDismiss:)])
                {
                    [self.delegate syncingDetailViewControllerWillDismiss:self];
                }
                
                [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
                    if ([self.delegate respondsToSelector:@selector(syncingDetailViewControllerDidDismiss:)])
                    {
                        [self.delegate syncingDetailViewControllerDidDismiss:self];
                    }
                }];
            }
        }];
    }
    else
    {
        if ([[GBASyncManager sharedManager] isSyncing] && [[GBASyncManager sharedManager] hasPendingDownloadForROM:self.rom] && ![self.rom syncingDisabled])
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Syncing with Dropbox", @"")
                                                            message:NSLocalizedString(@"Data for this game is currently being downloaded. To prevent data loss, please wait until the download is complete, then tap Done", @"")
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                                                  otherButtonTitles:nil];
            [alert show];
            
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(syncingDetailViewControllerWillDismiss:)])
        {
            [self.delegate syncingDetailViewControllerWillDismiss:self];
        }
        
        [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
            if ([self.delegate respondsToSelector:@selector(syncingDetailViewControllerDidDismiss:)])
            {
                [self.delegate syncingDetailViewControllerDidDismiss:self];
            }
        }];
    }
}

#pragma mark - Getters/Setters

- (DBRestClient *)restClient
{
    if (_restClient == nil)
    {
        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
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
