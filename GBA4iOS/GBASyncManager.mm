//
//  GBASyncManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncManager.h"
#import "GBASettingsViewController.h"

#import <sys/xattr.h>

#define SAVE_FILE_DIRECTORY_NAME @"Saves"

NSString *const GBAFileDeviceName = @"GBAFileDeviceName";

@interface GBASyncManager () <DBRestClientDelegate>
{
    BOOL _performingInitialSync;
}

@property (strong, nonatomic) DBRestClient *restClient;
@property (strong, nonatomic) NSMutableDictionary *pendingUploads; // Uses local filepath as keys
@property (strong, nonatomic) NSMutableDictionary *pendingDownloads; // Uses remote filepath as keys
@property (strong, nonatomic) NSMutableDictionary *remoteFiles; // Uses remote filepath as keys
@property (strong, nonatomic) NSMutableSet *conflictedROMs;
@property (strong, nonatomic) NSMutableSet *syncingDisabledROMs;
@property (strong, nonatomic) NSMutableSet *currentUploads; // Uses local filepaths
@property (strong, nonatomic) NSMutableSet *currentDownloads; // Uses remote filepaths
@property (strong, nonatomic) NSMutableDictionary *deviceUploadHistory;

@end

@implementation GBASyncManager

#pragma mark - Singleton Methods

+ (instancetype)sharedManager
{
    static GBASyncManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (id)init
{
    if (self = [super init])
    {
        _pendingUploads = [NSMutableDictionary dictionaryWithContentsOfFile:[self pendingUploadsPath]];
        
        if (_pendingUploads == nil)
        {
            _pendingUploads = [NSMutableDictionary dictionary];
        }
        
        _pendingDownloads = [NSMutableDictionary dictionaryWithContentsOfFile:[self pendingUploadsPath]];
        
        if (_pendingDownloads == nil)
        {
            _pendingDownloads = [NSMutableDictionary dictionary];
        }
        
        _deviceUploadHistory = [NSMutableDictionary dictionaryWithContentsOfFile:[self currentDeviceUploadHistoryPath]];
        
        if (_deviceUploadHistory == nil)
        {
            _deviceUploadHistory = [NSMutableDictionary dictionary];
        }
        
        _remoteFiles = [NSKeyedUnarchiver unarchiveObjectWithFile:[self remoteFilesPath]];
    
        if (_remoteFiles == nil)
        {
            _remoteFiles = [NSMutableDictionary dictionary];
        }
        
        _conflictedROMs = [[NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]] mutableCopy];
        _syncingDisabledROMs = [[NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]] mutableCopy];
        _currentUploads = [NSMutableSet set];
        _currentDownloads = [NSMutableSet set];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romConflictedStateDidChange:) name:GBAROMConflictedStateChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romSyncingDisabledStateDidChange:) name:GBAROMSyncingDisabledStateChanged object:nil];
    }
    return self;
}

- (void)dealloc
{
    // Should never be called, but just here for clarity really.
}

#pragma mark - Syncing

- (void)start
{
    DBSession *session = [[DBSession alloc] initWithAppKey:@"obzx8requbc5bn5" appSecret:@"thdkvkp3hkbmpte" root:kDBRootAppFolder];
    [DBSession setSharedSession:session];
    
    if (![[DBSession sharedSession] isLinked])
    {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsDropboxSyncKey];
    }
    else
    {
        self.restClient = [[DBRestClient alloc] initWithSession:session];
        self.restClient.delegate = self;
        //[self synchronize];
    }
}

- (void)synchronize
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey] || ![[DBSession sharedSession] isLinked])
    {
        return;
    }
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"hasPerformedInitialSync"])
    {
        return [self performInitialSync];
    }
    
    [self updateRemoteFiles];
}

#pragma mark - Initial Sync

- (void)performInitialSync
{
    if (_performingInitialSync)
    {
        return;
    }
    
    self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    self.restClient.delegate = self;
    
    _performingInitialSync = YES;
    
    [self.restClient loadDelta:nil];
}

- (void)uploadMissingFilesFromRemoteFiles:(NSArray *)files
{
    NSMutableDictionary *newRemoteFiles = [NSMutableDictionary dictionary];
    for (DBDeltaEntry *entry in files)
    {
        if (([entry.lowercasePath hasSuffix:@"sav"] || [entry.lowercasePath hasSuffix:@"plist"]) && ![entry.metadata isDeleted] && entry.metadata.path != nil)
        {
            [newRemoteFiles setObject:entry.metadata forKey:entry.metadata.path];
        }
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        if ([[[filename pathExtension] lowercaseString] isEqualToString:@"sav"])
        {
            NSString *romName = [filename stringByDeletingPathExtension];
            NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@", romName, filename];
            
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[documentsDirectory stringByAppendingPathComponent:filename] error:nil];
            
            DBMetadata *metadata = newRemoteFiles[dropboxPath];
            
            // If file doesn't exist on server, upload
            if (metadata == nil)
            {
                // Doesn't matter what extension is, we just need
                GBAROM *rom = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:[romName stringByAppendingPathExtension:@"gba"]]];
                [self prepareToUploadSaveFileForROM:rom];
                
            }
            else
            {
                DBMetadata *cachedMetadata = self.remoteFiles[dropboxPath];
                
                // If the cached rev doesn't match the server rev, it's conflicted
                if (![metadata.rev isEqualToString:cachedMetadata.rev])
                {
                    DLog(@"Cached Metadata: %@ Rev: %@ New Metadata: %@ Rom: %@", cachedMetadata, cachedMetadata.rev, metadata.rev, romName);
                    [self.conflictedROMs addObject:romName];
                    [self.syncingDisabledROMs addObject:romName];
                }
                else
                {
                    // If local and server rev match, but local file is newer than the previously cached metadata, upload it
                    // Bug in iOS 7, don't try to compare against [attributes fileModificationDate], IT'LL FAIL.
                    if ([cachedMetadata.lastModifiedDate laterDate:[attributes fileModificationDate]] != cachedMetadata.lastModifiedDate)
                    {
                        // Doesn't matter what extension is, we just need
                        GBAROM *rom = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:[romName stringByAppendingPathExtension:@"gba"]]];
                        [self prepareToUploadSaveFileForROM:rom];
                    }
                    else
                    {
                        //DLog(@"Not Replacing: %@", romName);
                        // Do nothing, the local file is the same as the one on the server
                    }
                }
                
            }
        }
    }
    
    self.remoteFiles = newRemoteFiles;
    [NSKeyedArchiver archiveRootObject:self.remoteFiles toFile:[self remoteFilesPath]];
    
    [[self.conflictedROMs allObjects] writeToFile:[self conflictedROMsPath] atomically:YES];
    [[self.syncingDisabledROMs allObjects] writeToFile:[self syncingDisabledROMsPath] atomically:YES];
    
    [self updateRemoteFiles];
    
    _performingInitialSync = NO;
}

#pragma mark - Update Remote Files

- (void)updateRemoteFiles
{
    NSDictionary *pendingUploads = [self.pendingUploads copy];
    
    if ([self pendingUploadsRemaining])
    {
        [pendingUploads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *uploadDictionary, BOOL *stop) {
            
            if (![uploadDictionary[@"uploaded"] boolValue])
            {
                NSString *localPath = uploadDictionary[@"localPath"];
                NSString *romName = [[localPath lastPathComponent] stringByDeletingPathExtension];
                NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@", romName, [romName stringByAppendingPathExtension:@"sav"]];
                
                DBMetadata *metadata = self.remoteFiles[dropboxPath];
                
                DLog(@"Replacing %@ Rev %@", uploadDictionary[@"remoteFilename"], metadata.rev);
                
                [self.restClient uploadFile:uploadDictionary[@"remoteFilename"] toPath:uploadDictionary[@"remoteDirectory"] withParentRev:metadata.rev fromPath:uploadDictionary[@"localPath"]];
                
                [self.currentUploads addObject:uploadDictionary[@"localPath"]];
            }
        }];
    }
    else
    {
        [self updateLocalFiles]; // No need to update upload history, since there were no files to upload
    }
}


- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath metadata:(DBMetadata *)metadata
{
    DLog(@"Uploaded File: %@ Rev: %@", srcPath, metadata.rev);
    
    if ([srcPath isEqualToString:[self currentDeviceUploadHistoryPath]])
    {
        [self updateLocalFiles];
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    // Different than source path
    NSString *originalPath = [documentsDirectory stringByAppendingPathComponent:[srcPath lastPathComponent]];
    
    NSMutableDictionary *dictionary = [self.pendingUploads[originalPath] mutableCopy];
    dictionary[@"uploaded"] = @YES;
    self.pendingUploads[originalPath] = dictionary;
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
    
    [self.remoteFiles setObject:metadata forKey:metadata.path];
    [NSKeyedArchiver archiveRootObject:self.remoteFiles toFile:[self remoteFilesPath]];
    
    NSDictionary *romDictionary = @{metadata.rev: metadata.path};
    [self.deviceUploadHistory setObject:romDictionary forKey:[[srcPath lastPathComponent] stringByDeletingPathExtension]];
    [self.deviceUploadHistory writeToFile:[self currentDeviceUploadHistoryPath] atomically:YES];
    
    [self.currentUploads removeObject:srcPath];
    
    if ([self.currentUploads count] == 0)
    {
        [self updateDeviceUploadHistory];
    }
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    DLog(@"Upload Failed :( %@", [error userInfo]);
    
    NSString *sourcePath = [error userInfo][@"sourcePath"];
    
    if ([sourcePath isEqualToString:[self currentDeviceUploadHistoryPath]])
    {
        [self updateLocalFiles];
        return;
    }
    
    [self.currentUploads removeObject:[error userInfo][@"sourcePath"]];
    
    if ([self.currentUploads count] == 0)
    {
        [self updateDeviceUploadHistory];
    }
    
}

#pragma mark - Update Device Upload History

- (void)updateDeviceUploadHistory
{
    NSString *deviceName = [[UIDevice currentDevice] name];
    
    // We're the only device to update the file, so we don't care about revisions
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    [self.restClient uploadFile:[deviceName stringByAppendingPathExtension:@"plist"] toPath:@"/Upload History/" fromPath:[self currentDeviceUploadHistoryPath]];
    
#pragma clang diagnostic pop
}

#pragma mark - Update Local Files

- (void)updateLocalFiles
{
    NSDictionary *lastSyncInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncInfo"];
    
    [self.restClient loadDelta:lastSyncInfo[@"cursor"]];
}

- (void)restClient:(DBRestClient *)client loadedDeltaEntries:(NSArray *)entries reset:(BOOL)shouldReset cursor:(NSString *)cursor hasMore:(BOOL)hasMore
{
    if (_performingInitialSync)
    {
        [self uploadMissingFilesFromRemoteFiles:entries];
        return;
    }
    
    NSDictionary *dictionary = @{@"date": [NSDate date], @"cursor": cursor};
    [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:@"lastSyncInfo"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    DLog(@"Download Local Files");
    
    for (DBDeltaEntry *entry in entries)
    {
        if ([[entry.lowercasePath pathExtension] isEqualToString:@"sav"])
        {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
            
            NSString *localPath = [documentsDirectory stringByAppendingPathComponent:entry.metadata.filename];
            [self prepareToDownloadFileWithMetadata:entry.metadata toPath:localPath conflictROMIfNeeded:YES];
            
        }
        else if ([[entry.lowercasePath stringByDeletingLastPathComponent] hasSuffix:@"upload history"] && [[entry.lowercasePath pathExtension] isEqualToString:@"plist"])
        {
            NSString *localPath = [[self uploadHistoryDirectoryPath] stringByAppendingPathComponent:entry.metadata.filename];
            [self prepareToDownloadFileWithMetadata:entry.metadata toPath:localPath conflictROMIfNeeded:NO];
        }
        
    }
    
    [self downloadPendingDownloads];
}

- (void)restClient:(DBRestClient*)client loadDeltaFailedWithError:(NSError *)error
{
    _performingInitialSync = NO;
    DLog(@"Delta Failed :(");
}

- (void)prepareToDownloadFileWithMetadata:(DBMetadata *)metadata toPath:(NSString *)localPath conflictROMIfNeeded:(BOOL)conflictROMIfNeeded
{
    if (![self.pendingUploads[localPath][@"uploaded"] boolValue] && ![self.syncingDisabledROMs containsObject:[metadata.filename stringByDeletingPathExtension]])
    {
        if (![metadata isDeleted] && metadata.path != nil && metadata.filename != nil)
        {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:localPath error:nil];
            DBMetadata *cachedMetadata = [self.remoteFiles objectForKey:metadata.path];
            
            // If local file hasn't been modified since last caching of remote file metadata
            // Bug in iOS 7, don't try to compare against cachedMetadata.lastModifiedDate, IT'LL FAIL.
            if ([[attributes fileModificationDate] laterDate:cachedMetadata.lastModifiedDate] != [attributes fileModificationDate] || attributes == nil)
            {
                [self.pendingDownloads setObject:@{@"rev": metadata.rev, @"localPath": localPath, @"dropboxPath": metadata.path} forKey:metadata.path];
                [self.pendingDownloads writeToFile:[self pendingDownloadsPath] atomically:YES];
            }
            else
            {
                if (conflictROMIfNeeded)
                {
                    NSString *romName = [metadata.filename stringByDeletingPathExtension];
                    DLog(@"Conflict downloading: %@ Rev: %@ New Metadata: %@ Rom: %@", cachedMetadata, cachedMetadata.rev, metadata.rev, romName);
                    [self.conflictedROMs addObject:romName];
                    [self.syncingDisabledROMs addObject:romName];
                }
                
            }
        }
        
    }
    else
    {
        [self.pendingUploads removeObjectForKey:localPath];
        [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
    }
}

- (void)downloadPendingDownloads
{
    NSDictionary *pendingDownloads = [self.pendingDownloads copy];
    
    if ([pendingDownloads count] > 0)
    {
        [pendingDownloads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *downloadDictionary, BOOL *stop) {
            
            NSString *localPath = downloadDictionary[@"localPath"];
            NSString *dropboxPath = downloadDictionary[@"dropboxPath"];
            
            [self.restClient loadFile:dropboxPath intoPath:localPath];
            
            [self.currentDownloads addObject:dropboxPath];
        }];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasPerformedInitialSync"];
    }
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath contentType:(NSString *)contentType metadata:(DBMetadata *)metadata
{
    DLog(@"Loaded File!: %@", destPath);
    
    [self.remoteFiles setObject:metadata forKey:metadata.path];
    [NSKeyedArchiver archiveRootObject:self.remoteFiles toFile:[self remoteFilesPath]];
    
    [self.pendingDownloads removeObjectForKey:metadata.path];
    [self.pendingDownloads writeToFile:[self pendingDownloadsPath] atomically:YES];
    
    [self.currentDownloads removeObject:metadata.path];
    
    if ([self.currentDownloads count] == 0)
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasPerformedInitialSync"];
    }
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error
{
    DLog(@"Failed to load file: %@", [error userInfo]);
    [self.currentDownloads removeObject:[error userInfo][@"sourcePath"]];
    
    if ([self.currentDownloads count] == 0)
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasPerformedInitialSync"];
    }
}

#pragma mark - Mark Files For Update

- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom
{
    if (rom == nil || [rom syncingDisabled] || ![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey] || ![[DBSession sharedSession] isLinked])
    {
        return;
    }
    
    DLog(@"Preparing to upload %@...", rom.name);
    
    NSString *savesDirectory = [NSString stringWithFormat:@"/%@/%@/", rom.name, SAVE_FILE_DIRECTORY_NAME];
    NSString *saveFileFilename = [rom.saveFileFilepath lastPathComponent];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *localPath = [documentsDirectory stringByAppendingPathComponent:saveFileFilename];
    
    [self prepareToUploadFileAtPath:localPath toDropboxPath:[savesDirectory stringByAppendingPathComponent:saveFileFilename]];
}

- (void)prepareToUploadFileAtPath:(NSString *)filepath toDropboxPath:(NSString *)dropboxPath
{
    NSDictionary *uploadDictionary = @{@"localPath": filepath, @"remoteDirectory": [dropboxPath stringByDeletingLastPathComponent], @"remoteFilename": [dropboxPath lastPathComponent], @"uploaded": @NO};
    
    [self.pendingUploads setObject:uploadDictionary forKey:filepath];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
}

#pragma mark - ROM Status

- (void)romConflictedStateDidChange:(NSNotification *)notification
{
    self.conflictedROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
}

- (void)romSyncingDisabledStateDidChange:(NSNotification *)notification
{
    self.syncingDisabledROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]];
}

#pragma mark - Application State

- (void)didEnterBackground:(NSNotification *)notification
{
    [self synchronize];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    [self synchronize];
}

#pragma mark - Helper Methods

- (BOOL)pendingUploadsRemaining
{
    NSDictionary *pendingUploads = [self.pendingUploads copy];
    
    __block BOOL pendingUploadsRemaining = NO;
    
    [pendingUploads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *uploadDictionary, BOOL *stop) {
        if (![uploadDictionary[@"uploaded"] boolValue])
        {
            pendingUploadsRemaining = YES;
        }
    }];
    
    return pendingUploadsRemaining;
}

- (NSString *)dropboxSyncDirectoryPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dropboxDirectory = [libraryDirectory stringByAppendingPathComponent:@"Dropbox Sync"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:dropboxDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return dropboxDirectory;
}

- (NSString *)pendingUploadsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"pendingUploads.plist"];
}

- (NSString *)pendingDownloadsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"pendingDownloads.plist"];
}

- (NSString *)remoteFilesPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"remoteFiles.plist"];
}

- (NSString *)conflictedROMsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"conflictedROMs.plist"];
}

- (NSString *)syncingDisabledROMsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"syncingDisabledROMs.plist"];
}

- (NSString *)uploadHistoryDirectoryPath
{
    NSString *directory = [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"Upload History"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}

- (NSString *)currentDeviceUploadHistoryPath
{
    NSString *deviceName = [[UIDevice currentDevice] name];
    return [[self uploadHistoryDirectoryPath] stringByAppendingPathComponent:[deviceName stringByAppendingPathExtension:@"plist"]];
}

@end
