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

NSString * const GBASyncingLocalPath = @"localPath";
NSString * const GBASyncingDropboxPath = @"dropboxPath";
NSString * const GBASyncingFileType = @"fileType";
NSString * const GBASyncingFileRev = @"rev";

typedef NS_ENUM(NSInteger, GBADropboxFileType)
{
    GBADropboxFileTypeUnknown             = 0,
    GBADropboxFileTypeSave                = 1,
    GBADropboxFileTypeSaveState           = 2,
    GBADropboxFileTypeCheat               = 3,
    GBADropboxFileTypeUploadHistory       = 4,
};

NSString *const GBAFileDeviceName = @"GBAFileDeviceName";

@interface GBASyncManager () <DBRestClientDelegate>
{
    BOOL _performingInitialSync;
}

@property (strong, nonatomic) DBRestClient *restClient;

@property (strong, nonatomic) NSMutableDictionary *dropboxFiles; // Uses remote filepath as keys
@property (strong, nonatomic) NSSet *conflictedROMs;
@property (strong, nonatomic) NSSet *syncingDisabledROMs;
@property (strong, nonatomic) NSMutableDictionary *deviceUploadHistory;

@property (strong, nonatomic) NSMutableDictionary *pendingUploads; // Uses local filepath as keys
@property (strong, nonatomic) NSMutableDictionary *pendingDownloads; // Uses remote filepath as keys
@property (strong, nonatomic) NSMutableSet *currentUploads; // Uses local filepaths
@property (strong, nonatomic) NSMutableSet *currentDownloads; // Uses remote filepaths

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
        
        _dropboxFiles = [NSKeyedUnarchiver unarchiveObjectWithFile:[self dropboxFilesPath]];
    
        if (_dropboxFiles == nil)
        {
            _dropboxFiles = [NSMutableDictionary dictionary];
        }
        
        _conflictedROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
        _syncingDisabledROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]];
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
    
    NSDictionary *lastSyncInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncInfo"];
    [self.restClient loadDelta:lastSyncInfo[@"cursor"]];
}

- (void)restClient:(DBRestClient *)client loadedDeltaEntries:(NSArray *)entries reset:(BOOL)shouldReset cursor:(NSString *)cursor hasMore:(BOOL)hasMore
{
    NSDictionary *dictionary = @{@"date": [NSDate date], @"cursor": cursor};
    [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:@"lastSyncInfo"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    for (DBDeltaEntry *entry in entries)
    {
        if ([[entry.lowercasePath pathExtension] isEqualToString:@"sav"])
        {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
            
            NSString *localPath = [documentsDirectory stringByAppendingPathComponent:entry.metadata.filename];
            [self prepareToDownloadFileWithMetadata:entry.metadata toPath:localPath fileType:GBADropboxFileTypeSave conflictROMIfNeeded:YES];
            
        }
        else if ([[entry.lowercasePath stringByDeletingLastPathComponent] hasSuffix:@"upload history"] && [[entry.lowercasePath pathExtension] isEqualToString:@"plist"])
        {
            NSString *localPath = [[self uploadHistoryDirectoryPath] stringByAppendingPathComponent:entry.metadata.filename];
            [self prepareToDownloadFileWithMetadata:entry.metadata toPath:localPath fileType:GBADropboxFileTypeUploadHistory conflictROMIfNeeded:NO];
        }
        
    }
    
    DLog(@"Pending Downloads: %@", self.pendingDownloads);
    
    if (_performingInitialSync)
    {
        [self uploadFilesMissingFromRemoteFiles:entries];
    }
    else
    {
        [self updateRemoteFiles];
    }
    
}

- (void)restClient:(DBRestClient*)client loadDeltaFailedWithError:(NSError *)error
{
    _performingInitialSync = NO;
    DLog(@"Delta Failed :(");
}

#pragma mark - Initial Sync

- (void)performInitialSync
{
    DLog(@"Actually performing initial sync");
    
    if (_performingInitialSync)
    {
        return;
    }
    
    self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    self.restClient.delegate = self;
    
    _performingInitialSync = YES;
    
    [self.restClient loadDelta:nil];
}

- (void)uploadFilesMissingFromRemoteFiles:(NSArray *)files
{
    DLog(@"Input Files: %@", files);
    NSMutableDictionary *newDropboxFiles = [NSMutableDictionary dictionary];
    for (DBDeltaEntry *entry in files)
    {
        if ([entry.metadata isDeleted] || entry.metadata.path == nil)
        {
            continue;
        }
        
        if ([entry.lowercasePath hasSuffix:@"sav"] || [entry.lowercasePath hasSuffix:@"plist"])
        {
            [newDropboxFiles setObject:entry.metadata forKey:entry.metadata.path];
        }
    }
    
    DLog(@"Dropbox Files: %@", newDropboxFiles);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        if (![[[filename pathExtension] lowercaseString] isEqualToString:@"sav"])
        {
            continue;
        }
        
        NSString *romName = [filename stringByDeletingPathExtension];
        NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@", romName, filename];
        
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[documentsDirectory stringByAppendingPathComponent:filename] error:nil];
        
        DBMetadata *dropboxMetadata = newDropboxFiles[dropboxPath];
        
        // If file doesn't exist on server, upload
        if (dropboxMetadata == nil)
        {
            DLog(@"Dropbox Path: %@", dropboxPath);
            
            // Doesn't matter what extension is, we just need a dummy ROM
            GBAROM *rom = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:[romName stringByAppendingPathExtension:@"gba"]]];
            [self prepareToUploadSaveFileForROM:rom];
        }
        else
        {
            DBMetadata *cachedMetadata = self.dropboxFiles[dropboxPath];
            
            // If the cached rev doesn't match the server rev, it's conflicted
            if (![dropboxMetadata.rev isEqualToString:cachedMetadata.rev])
            {
                DLog(@"Conflicted ROM: %@ Local Rev: %@ Dropbox Rev: %@", romName, cachedMetadata.rev, dropboxMetadata.rev);
                
                GBAROM *dummyROM = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:[romName stringByAppendingPathExtension:@"gba"]]];
                [dummyROM setConflicted:YES];
                [dummyROM setSyncingDisabled:YES];
            }
            else
            {
                // If local and server rev match, but local file is newer than the previously cached metadata, upload it
                // Bug in iOS 7, don't try "== [attributes fileModificationDate]", returns NO.
                if ([cachedMetadata.lastModifiedDate laterDate:[attributes fileModificationDate]] != cachedMetadata.lastModifiedDate)
                {
                    // Doesn't matter what extension is, we just need a dummy ROM
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
    
    self.dropboxFiles = newDropboxFiles;
    [NSKeyedArchiver archiveRootObject:self.dropboxFiles toFile:[self dropboxFilesPath]];
    
    [self updateRemoteFiles];
    
    _performingInitialSync = NO;
}

#pragma mark - Update Remote Files

- (void)updateRemoteFiles
{
    NSDictionary *pendingUploads = [self.pendingUploads copy];
    
    if ([pendingUploads count] > 0)
    {
        [pendingUploads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *uploadDictionary, BOOL *stop) {
            
            NSString *localPath = uploadDictionary[GBASyncingLocalPath];
            NSString *dropboxPath = uploadDictionary[GBASyncingDropboxPath];
            GBADropboxFileType fileType = (GBADropboxFileType)[uploadDictionary[GBASyncingFileType] integerValue];
            
            NSArray *components = [dropboxPath componentsSeparatedByString:@"/"];
            if (components.count > 1 && fileType != GBADropboxFileTypeUploadHistory)
            {
                NSString *romName = components[1];
                
                if ([self.syncingDisabledROMs containsObject:romName])
                {
                    return;
                }
            }
            
            DBMetadata *metadata = self.dropboxFiles[dropboxPath];
            
            if (metadata.rev)
            {
                DLog(@"Uploading %@... (Replacing Rev %@)", [dropboxPath lastPathComponent], metadata.rev);
            }
            else
            {
                DLog(@"Uploading %@...", [dropboxPath lastPathComponent]);
            }
            
            [self.currentUploads addObject:localPath];
            
            [self.restClient uploadFile:[dropboxPath lastPathComponent] toPath:[dropboxPath stringByDeletingLastPathComponent] withParentRev:metadata.rev fromPath:localPath];
            
        }];
    }
    else
    {
        [self updateLocalFiles]; // No need to update upload history, since there were no files to upload
    }
}

- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom
{
    if (rom == nil || ![[DBSession sharedSession] isLinked])
    {
        return;
    }
    
    NSString *saveFileFilepath = [NSString stringWithFormat:@"/%@/%@/%@", rom.name, SAVE_FILE_DIRECTORY_NAME, [rom.saveFileFilepath lastPathComponent]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [self prepareToUploadFileAtPath:rom.saveFileFilepath toDropboxPath:saveFileFilepath fileType:GBADropboxFileTypeSave];
}

- (void)prepareToUploadFileAtPath:(NSString *)filepath toDropboxPath:(NSString *)dropboxPath fileType:(GBADropboxFileType)fileType
{
    NSDictionary *uploadDictionary = @{GBASyncingLocalPath: filepath, GBASyncingDropboxPath: dropboxPath, GBASyncingFileType: @(fileType)};
    
    [self.pendingUploads setObject:uploadDictionary forKey:filepath];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
}


- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath metadata:(DBMetadata *)metadata
{
    DLog(@"Uploaded File: %@ To Path: %@ Rev: %@", srcPath, destPath, metadata.rev);
    
    if ([srcPath isEqualToString:[self currentDeviceUploadHistoryPath]])
    {
        [self updateLocalFiles];
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [self.pendingUploads removeObjectForKey:srcPath];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
    
    [self.dropboxFiles setObject:metadata forKey:metadata.path];
    [NSKeyedArchiver archiveRootObject:self.dropboxFiles toFile:[self dropboxFilesPath]];
    
    NSString *romName = [[srcPath lastPathComponent] stringByDeletingPathExtension];
    NSMutableDictionary *romDictionary = [self.deviceUploadHistory[romName] mutableCopy];
    
    if (romDictionary == nil)
    {
        romDictionary = [NSMutableDictionary dictionary];
    }
    
    romDictionary[metadata.path] = metadata.rev;
    
    [self.deviceUploadHistory setObject:romDictionary forKey:romName];
    [self.deviceUploadHistory writeToFile:[self currentDeviceUploadHistoryPath] atomically:YES];
    
    [self.currentUploads removeObject:srcPath];
    
    if (![destPath.lowercaseString isEqualToString:[metadata.path lowercaseString]])
    {
        DLog(@"Conflicted upload for file: %@ Destination Path: %@ Actual Path: %@", metadata.filename, destPath, metadata.path);
        NSString *romName = [[srcPath lastPathComponent] stringByDeletingPathExtension];
        GBAROM *dummyROM = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:[romName stringByAppendingPathExtension:@"gba"]]];
        [dummyROM setConflicted:YES];
    }
    
    if ([self.currentUploads count] == 0)
    {
        [self updateDeviceUploadHistory];
    }
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
     NSString *sourcePath = [error userInfo][@"sourcePath"];
    
    DLog(@"Failed to upload file: %@ Error: %@", [sourcePath lastPathComponent], [error userInfo]);
    
    if ([sourcePath isEqualToString:[self currentDeviceUploadHistoryPath]])
    {
        [self updateLocalFiles];
        return;
    }
    
    [self.currentUploads removeObject:sourcePath];
    
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
    NSDictionary *pendingDownloads = [self.pendingDownloads copy];
    
    DLog(@"Pending Downloads: %@", pendingDownloads);

    if ([pendingDownloads count] > 0)
    {
        [pendingDownloads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *downloadDictionary, BOOL *stop) {
            
            NSString *localPath = downloadDictionary[GBASyncingLocalPath];
            NSString *dropboxPath = downloadDictionary[GBASyncingDropboxPath];
            GBADropboxFileType fileType = (GBADropboxFileType)[downloadDictionary[GBASyncingFileType] integerValue];
            
            NSArray *components = [dropboxPath componentsSeparatedByString:@"/"];
            if (components.count > 1 && fileType != GBADropboxFileTypeUploadHistory)
            {
                NSString *romName = components[1];
                
                if ([self.syncingDisabledROMs containsObject:romName] || (![self romExistsWithName:romName] && fileType == GBADropboxFileTypeSave))
                {
                    return;
                }
            }
            
            [self.currentDownloads addObject:dropboxPath];
            [self.restClient loadFile:dropboxPath intoPath:localPath];
            
        }];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasPerformedInitialSync"];
    }
}

- (void)prepareToDownloadFileWithMetadata:(DBMetadata *)metadata toPath:(NSString *)localPath fileType:(GBADropboxFileType)fileType conflictROMIfNeeded:(BOOL)conflictROMIfNeeded
{
    if ([metadata isDeleted] || metadata.path == nil || metadata.filename == nil)
    {
        return;
    }
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:localPath error:nil];
    DBMetadata *cachedMetadata = [self.dropboxFiles objectForKey:metadata.path];
    
    // If local file hasn't been modified since last caching of remote file metadata
    // Bug in iOS 7, don't try to compare against cachedMetadata.lastModifiedDate, IT'LL FAIL.
    if ([[attributes fileModificationDate] laterDate:cachedMetadata.lastModifiedDate] != [attributes fileModificationDate] || attributes == nil)
    {
        [self.pendingDownloads setObject:@{GBASyncingFileRev: metadata.rev, GBASyncingLocalPath: localPath, GBASyncingDropboxPath: metadata.path, GBASyncingFileType:@(fileType)} forKey:metadata.path];
        [self.pendingDownloads writeToFile:[self pendingDownloadsPath] atomically:YES];
    }
    else
    {
        if (conflictROMIfNeeded)
        {
            NSString *romName = [metadata.filename stringByDeletingPathExtension];
            DLog(@"Conflict downloading file: %@ Rev: %@ Cached Metadata: %@ New Metadata: %@", metadata.filename, metadata.rev, cachedMetadata.rev, metadata);
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
            
            GBAROM *dummyROM = [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:[romName stringByAppendingPathExtension:@"gba"]]];
            [dummyROM setConflicted:YES];
            [dummyROM setSyncingDisabled:YES];
        }
        
    }
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)downloadedPath contentType:(NSString *)contentType metadata:(DBMetadata *)metadata
{
    DLog(@"Loaded File: %@", downloadedPath);
    
    [self.dropboxFiles setObject:metadata forKey:metadata.path];
    [NSKeyedArchiver archiveRootObject:self.dropboxFiles toFile:[self dropboxFilesPath]];
    
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
    NSString *sourcePath = [error userInfo][@"sourcePath"];
    
    DLog(@"Failed to load file: %@ Error: %@", [sourcePath lastPathComponent], [error userInfo]);
    [self.currentDownloads removeObject:sourcePath];
    
    if ([self.currentDownloads count] == 0)
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasPerformedInitialSync"];
    }
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

- (BOOL)romExistsWithName:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(pathExtension.lowercaseString == 'gba') OR (pathExtension.lowercaseString == 'gbc') OR (pathExtension.lowercaseString == 'gb')"];
    NSMutableArray *contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil] mutableCopy];
    [contents filterUsingPredicate:predicate];
    
    for (NSString *filename in contents)
    {
        if ([[filename stringByDeletingPathExtension] isEqualToString:name])
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Filepathss

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

- (NSString *)dropboxFilesPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"dropboxFiles.plist"];
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
