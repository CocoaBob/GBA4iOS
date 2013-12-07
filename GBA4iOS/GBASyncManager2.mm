//
//  GBASyncManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncManager_Private.h"
#import "GBASettingsViewController.h"
#import "UIAlertView+RSTAdditions.h"
#import "RSTToastView.h"
#import "GBASyncingOverviewViewController.h"

#if !(TARGET_IPHONE_SIMULATOR)
#import "GBAEmulatorCore.h"
#endif

#import <sys/xattr.h>

#define SAVE_FILE_DIRECTORY_NAME @"Saves"

NSString * const GBASyncingLocalPathKey = @"localPath";
NSString * const GBASyncingDropboxPathKey = @"dropboxPath";
NSString * const GBASyncingFileTypeKey = @"fileType";
NSString * const GBASyncingFileRevKey = @"rev";
NSString * const GBASyncingBackgroundTaskIdentifierKey = @"backgroundTaskIdentifier";
NSString * const GBASyncingCompletionBlockKey = @"completionBlock";
NSString * const GBASyncingSingleFileKey = @"singleFile";

@interface GBASyncManager () <DBRestClientDelegate>
{
    BOOL _performingInitialSync;
}

@property (strong, nonatomic) DBRestClient *restClient;
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (assign, nonatomic) NSInteger syncingTaskCount;
@property (assign, nonatomic) BOOL syncingAllFiles;

@property (strong, nonatomic) NSMutableDictionary *dropboxFiles; // Uses remote filepath as keys
@property (strong, nonatomic) NSSet *conflictedROMs;
@property (strong, nonatomic) NSSet *syncingDisabledROMs;
@property (strong, nonatomic) NSMutableDictionary *deviceUploadHistory;

@property (strong, nonatomic) NSMutableDictionary *pendingUploads; // Uses local filepath as keys
@property (strong, nonatomic) NSMutableDictionary *pendingDownloads; // Uses remote filepath as keys
@property (strong, nonatomic) NSMutableDictionary *currentUploads; // Uses local filepaths
@property (strong, nonatomic) NSMutableDictionary *currentDownloads; // Uses remote filepaths

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
        
        // Remember to empty these all when user logs out of dropbox!!
        
        _pendingUploads = [NSMutableDictionary dictionaryWithContentsOfFile:[self pendingUploadsPath]];
        
        if (_pendingUploads == nil)
        {
            _pendingUploads = [NSMutableDictionary dictionary];
        }
        
        _pendingDownloads = [NSMutableDictionary dictionaryWithContentsOfFile:[self pendingDownloadsPath]];
        
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
        _currentUploads = [NSMutableDictionary dictionary];
        _currentDownloads = [NSMutableDictionary dictionary];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romConflictedStateDidChange:) name:GBAROMConflictedStateChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romSyncingDisabledStateDidChange:) name:GBAROMSyncingDisabledStateChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLoggedOut:) name:GBADropboxLoggedOutNotification object:nil];
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
    
    self.shouldShowSyncingStatus = YES;
    
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (self.shouldShowSyncingStatus)
        {
            //[RSTToastView showWithActivityMessage:@"Booting up RAM"];
        }
    });
    
    
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
    if (![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey] || ![[DBSession sharedSession] isLinked] || self.syncingAllFiles || _performingInitialSync)
    {
        return;
    }
    
    self.syncingTaskCount++;
    self.syncingAllFiles = YES;
    
    if (self.shouldShowSyncingStatus)
    {
        [RSTToastView showWithActivityMessage:@"Syncing..."];
    }
    
    self.backgroundTaskIdentifier = rst_begin_background_task();
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"initialSync"])
    {
        return [self performInitialSync];
    }
    
    DLog(@"Syncing with dropbox...");
    NSDictionary *lastSyncInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncInfo"];
    [self.restClient loadDelta:lastSyncInfo[@"cursor"]];
}

- (void)restClient:(DBRestClient *)client loadedDeltaEntries:(NSArray *)entries reset:(BOOL)shouldReset cursor:(NSString *)cursor hasMore:(BOOL)hasMore
{
    
    NSDictionary *dictionary = @{@"date": [NSDate date], @"cursor": cursor};
    [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:@"lastSyncInfo"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    DLog(@"Received Delta Entries");
    
    NSDictionary *dropboxFiles = [self dropboxFilesFromDeltaEntries:entries];
    [dropboxFiles enumerateKeysAndObjectsUsingBlock:^(NSString *key, DBMetadata *metadata, BOOL *stop) {
        [self prepareToDownloadFileWithMetadataIfNeeded:metadata];
    }];
    
    
    if (_performingInitialSync)
    {
        [self uploadFilesMissingFromDropboxFiles:dropboxFiles];
    }
    else
    {
        [self updateRemoteFiles];
    }
    
}

- (void)restClient:(DBRestClient*)client loadDeltaFailedWithError:(NSError *)error
{
    DLog(@"Delta Failed :(");
    
    // Don't want to save that we did the initial sync of the delta failed, so we set _performingInitialSync to NO
    _performingInitialSync = NO;
    [self finishSyncingWithCompletionMessage:NSLocalizedString(@"Failed to sync with Dropbox", @"") duration:2];
}

- (void)finishSyncingWithCompletionMessage:(NSString *)message duration:(NSTimeInterval)duration
{
    DLog(@"Finished Syncing!");
    self.syncingTaskCount--;
    
    if (self.syncingTaskCount <= 0)
    {
        if (self.shouldShowSyncingStatus)
        {
            [RSTToastView showWithMessage:message duration:duration];
        }
        
        // Sure, by waiting until all tasks are complete to set this to NO may delay it a bit, but it doesn't add too much more complexity to the code
        self.syncingAllFiles = NO;
        
        self.syncingTaskCount = 0;
    }
    
    if (_performingInitialSync)
    {
        // Even if it failed, we still consider the sync completed (so the user can play games anyway)
        [[NSUserDefaults standardUserDefaults] setObject:@{@"date": [NSDate date], @"completed": @YES} forKey:@"initialSync"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        _performingInitialSync = NO;
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid)
    {
        rst_end_background_task(self.backgroundTaskIdentifier);
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }    
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

- (void)uploadFilesMissingFromDropboxFiles:(NSDictionary *)newDropboxFiles
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        NSString *filepath = [documentsDirectory stringByAppendingPathComponent:filename];
        
        if (![[[filename pathExtension] lowercaseString] isEqualToString:@"sav"])
        {
            continue;
        }
        
        NSString *romName = [filename stringByDeletingPathExtension];
        
        GBAROM *rom = [GBAROM romWithName:romName];
        
        if (rom == nil)
        {
            continue;
        }
        
        NSString *embeddedName = [rom embeddedName];
        
        NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@", embeddedName, [embeddedName stringByAppendingPathExtension:@"sav"]];
        
        // Already uploaded, don't need to upload again
        if (self.pendingUploads[filepath])
        {
            continue;
        }
        
        [self prepareToInitiallyUploadFileAtPathIfNeeded:filepath toDropboxPath:dropboxPath withNewDropboxFiles:newDropboxFiles];
    }
    
    self.dropboxFiles = [newDropboxFiles mutableCopy];
    [NSKeyedArchiver archiveRootObject:self.dropboxFiles toFile:[self dropboxFilesPath]];
    
    // So we don't have to perform this initial sync step again
    [[NSUserDefaults standardUserDefaults] setObject:@{@"date": [NSDate date], @"completed": @NO} forKey:@"initialSync"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self updateRemoteFiles];
}

- (void)prepareToInitiallyUploadFileAtPathIfNeeded:(NSString *)localPath toDropboxPath:(NSString *)dropboxPath withNewDropboxFiles:(NSDictionary *)newDropboxFiles
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *romName = [self romNameFromDropboxPath:dropboxPath];
    
    GBAROM *rom = [GBAROM romWithName:romName];
    
    DBMetadata *dropboxMetadata = newDropboxFiles[dropboxPath];
    DBMetadata *cachedMetadata = self.dropboxFiles[dropboxPath];
    
    if ([dropboxMetadata.rev isEqualToString:cachedMetadata.rev] && dropboxMetadata != nil)
    {
        return;
    }
    
    // If the cached rev doesn't match the server rev, it's conflicted
    if (![dropboxMetadata.rev isEqualToString:cachedMetadata.rev] && dropboxMetadata != nil)
    {
        DLog(@"Conflicted ROM: %@ Local Rev: %@ Dropbox Rev: %@", romName, cachedMetadata.rev, dropboxMetadata.rev);
        
        [rom setConflicted:YES];
        [rom setSyncingDisabled:YES];
    }
    else
    {
        [self prepareToUploadSaveFileForROM:rom];
    }
}

#pragma mark - Update Remote Files

- (void)updateRemoteFiles
{
    NSDictionary *pendingUploads = [self.pendingUploads copy];
    
    if ([pendingUploads count] > 0)
    {
        [pendingUploads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *uploadDictionary, BOOL *stop) {
            
            NSString *localPath = uploadDictionary[GBASyncingLocalPathKey];
            NSString *dropboxPath = uploadDictionary[GBASyncingDropboxPathKey];
            GBADropboxFileType fileType = (GBADropboxFileType)[uploadDictionary[GBASyncingFileTypeKey] integerValue];
            
            if (fileType != GBADropboxFileTypeUploadHistory)
            {
                NSString *romName = [self romNameFromDropboxPath:dropboxPath];
                
                if ([self.syncingDisabledROMs containsObject:romName])
                {
                    DLog(@"Syncing turned off for ROM: %@", romName);
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
            
            // Any logic you change here should be changed in uploadFileAtPath:toDropboxPath:withMetadata:fileType: too
            [self.currentUploads setObject:@{GBASyncingDropboxPathKey: dropboxPath, GBASyncingLocalPathKey: localPath} forKey:localPath];
            
            DLog(@"DBP: %@ Metadata: %@ Local: %@", dropboxPath, metadata, localPath);
            
            [self.restClient uploadFile:[dropboxPath lastPathComponent] toPath:[dropboxPath stringByDeletingLastPathComponent] withParentRev:metadata.rev fromPath:localPath];
            
        }];
        
        if ([self.currentUploads count] == 0)
        {
            [self updateLocalFiles]; // No need to update upload history, since there were no files to upload
        }
        else
        {
            [RSTToastView updateWithActivityMessage:NSLocalizedString(@"Uploading Files…", @"")];
        }
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
    
    NSString *embeddedName = [rom embeddedName];
    NSString *saveFileFilepath = [NSString stringWithFormat:@"/%@/%@/%@", embeddedName, SAVE_FILE_DIRECTORY_NAME, [embeddedName stringByAppendingPathExtension:@"sav"]];
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:rom.saveFileFilepath error:nil];
    DBMetadata *cachedMetadata = [self.dropboxFiles objectForKey:saveFileFilepath];
    
    [self prepareToUploadFileAtPath:rom.saveFileFilepath toDropboxPath:saveFileFilepath fileType:GBADropboxFileTypeSave singleFile:NO];
}

- (void)prepareToUploadFileAtPath:(NSString *)filepath toDropboxPath:(NSString *)dropboxPath fileType:(GBADropboxFileType)fileType singleFile:(BOOL)singleFile
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filepath])
    {
        return;
    }
    
    NSDictionary *uploadDictionary = @{GBASyncingLocalPathKey: filepath, GBASyncingDropboxPathKey: dropboxPath, GBASyncingFileTypeKey: @(fileType), GBASyncingSingleFileKey: @(singleFile)};
    
    [self.pendingUploads setObject:uploadDictionary forKey:filepath];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
}

- (void)uploadFileAtPath:(NSString *)path withMetadata:(DBMetadata *)metadata fileType:(GBADropboxFileType)fileType completionBlock:(GBASyncingCompletionBlock)completionBlock
{
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = rst_begin_background_task();
    
    self.syncingTaskCount++;
    
    self.dropboxFiles[metadata.path] = metadata;
    
    [self prepareToUploadFileAtPath:path toDropboxPath:metadata.path fileType:fileType singleFile:YES];
    
    // Won't be downloading, and we don't want to return YES for isDownloadingFile, so remove it from pendingDownloads
    [self.pendingDownloads removeObjectForKey:metadata.path];
    [self.pendingDownloads writeToFile:[self pendingDownloadsPath] atomically:YES];
    
    if (metadata.rev)
    {
        DLog(@"Uploading %@... (Replacing Rev %@)", [metadata.path lastPathComponent], metadata.rev);
    }
    else
    {
        DLog(@"Uploading %@...", [metadata.path lastPathComponent]);
    }
    
    NSMutableDictionary *dictionary = [@{GBASyncingLocalPathKey: path, GBASyncingDropboxPathKey: metadata.path, GBASyncingBackgroundTaskIdentifierKey: @(backgroundTaskIdentifier)} mutableCopy];
    
    if (completionBlock)
    {
        dictionary[GBASyncingCompletionBlockKey] = [completionBlock copy];
    }
    
    [self.currentUploads setObject:dictionary forKey:path];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.shouldShowSyncingStatus)
        {
            [RSTToastView showWithActivityMessage:@"Uploading..."];
        }
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    });
    
    [self.restClient uploadFile:metadata.filename toPath:[metadata.path stringByDeletingLastPathComponent] withParentRev:metadata.rev fromPath:path];
}


- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath metadata:(DBMetadata *)metadata
{
    DLog(@"Uploaded File: %@ To Path: %@ Rev: %@", srcPath, destPath, metadata.rev);
    
    // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
    NSDictionary *attributes = @{NSFileModificationDate: metadata.lastModifiedDate};
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:srcPath error:nil];
    
    [self.dropboxFiles setObject:metadata forKey:metadata.path];
    [NSKeyedArchiver archiveRootObject:self.dropboxFiles toFile:[self dropboxFilesPath]];
    
    if ([srcPath isEqualToString:[self currentDeviceUploadHistoryPath]])
    {
        [self updateLocalFiles];
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [self.pendingUploads removeObjectForKey:srcPath];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
    
    NSString *embeddedName = [self embededdROMNameFromDropboxPath:destPath];
    NSMutableDictionary *romDictionary = [self.deviceUploadHistory[embeddedName] mutableCopy];
    
    if (romDictionary == nil)
    {
        romDictionary = [NSMutableDictionary dictionary];
    }
    
    romDictionary[metadata.path] = metadata.rev;
    
    [self.deviceUploadHistory setObject:romDictionary forKey:embeddedName];
    [self.deviceUploadHistory writeToFile:[self currentDeviceUploadHistoryPath] atomically:YES];
    
    if (![destPath.lowercaseString isEqualToString:[metadata.path lowercaseString]])
    {
        DLog(@"Conflicted upload for file: %@ Destination Path: %@ Actual Path: %@", metadata.filename, destPath, metadata.path);
        NSString *romName = [[srcPath lastPathComponent] stringByDeletingPathExtension];
        GBAROM *rom = [GBAROM romWithName:romName];
        [rom setConflicted:YES];
        [rom setSyncingDisabled:YES];
    }
    
    [self handleCompletedUploadForFileAtPath:srcPath withError:nil shouldContinue:YES];
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    NSString *sourcePath = [error userInfo][@"sourcePath"];
    
    if ([error code] == DBErrorFileNotFound) // Not really an error, so we ignore it
    {
        DLog(@"File doesn't exist for upload...ignoring %@", [sourcePath lastPathComponent]);
        
        [self.pendingUploads removeObjectForKey:sourcePath];
        [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
        
        [self handleCompletedUploadForFileAtPath:sourcePath withError:nil shouldContinue:YES];
        
        return;
    }
    
    DLog(@"Failed to upload file: %@ Error: %@", [sourcePath lastPathComponent], [error userInfo]);
    
    NSDictionary *uploadDictionary = self.currentUploads[sourcePath];
    
    BOOL shouldContinue = YES;
    
    // For sake of code simplicity, if the single file upload fails, we just end the sync so we can display our error message.
    if ([uploadDictionary[GBASyncingSingleFileKey] boolValue])
    {
        shouldContinue = NO;
        [self finishSyncingWithCompletionMessage:NSLocalizedString(@"Upload Failed", @"") duration:1.0];
    }
    
    if ([sourcePath isEqualToString:[self currentDeviceUploadHistoryPath]])
    {
        [self updateLocalFiles];
        return;
    }
    
    [self handleCompletedUploadForFileAtPath:sourcePath withError:error shouldContinue:shouldContinue];
}

- (void)handleCompletedUploadForFileAtPath:(NSString *)path withError:(NSError *)error shouldContinue:(BOOL)shouldContinue
{
    NSDictionary *uploadDictionary = self.currentUploads[path];
    
    GBASyncingCompletionBlock completionBlock = uploadDictionary[GBASyncingCompletionBlockKey];
    
    if (completionBlock)
    {
        completionBlock(path, uploadDictionary[GBASyncingDropboxPathKey], nil);
    }
    
    if (uploadDictionary[GBASyncingBackgroundTaskIdentifierKey])
    {
        UIBackgroundTaskIdentifier identifier = [uploadDictionary[GBASyncingBackgroundTaskIdentifierKey] unsignedIntegerValue];
                
        rst_end_background_task(identifier);
        // Sure, it ends the background task before we update the device history, but it shouldn't be that much of a problem.
    }
    
    [self.currentUploads removeObjectForKey:path];
    
    if ([self.currentUploads count] == 0 && shouldContinue)
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
    
    if ([pendingDownloads count] > 0)
    {
        [pendingDownloads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *downloadDictionary, BOOL *stop) {
            
            NSString *localPath = downloadDictionary[GBASyncingLocalPathKey];
            NSString *dropboxPath = downloadDictionary[GBASyncingDropboxPathKey];
            GBADropboxFileType fileType = (GBADropboxFileType)[downloadDictionary[GBASyncingFileTypeKey] integerValue];
            
            if (fileType != GBADropboxFileTypeUploadHistory)
            {
                NSString *romName = [self romNameFromDropboxPath:dropboxPath];
                
                if ([self.syncingDisabledROMs containsObject:romName] || (![self romExistsWithName:romName] && fileType == GBADropboxFileTypeSave))
                {
                    return;
                }
            }
            
            // Make sure to update anything you change here in downloadFileWithMetadata:toPath:fileType:completionBlock:
            
            [self.currentDownloads setObject:@{GBASyncingDropboxPathKey: dropboxPath, GBASyncingLocalPathKey: localPath} forKey:dropboxPath];
            [self.restClient loadFile:dropboxPath intoPath:localPath];
            
        }];
        
        if ([self.currentDownloads count] == 0)
        {
            [self finishSyncingWithCompletionMessage:NSLocalizedString(@"Sync Complete!", @"") duration:1];
        }
        else
        {
            [RSTToastView updateWithActivityMessage:NSLocalizedString(@"Downloading Files…", @"")];
        }
    }
    else
    {
        [self finishSyncingWithCompletionMessage:NSLocalizedString(@"Sync Complete!", @"") duration:1];
    }
}

- (void)prepareToDownloadFileWithMetadataIfNeeded:(DBMetadata *)metadata
{
    DBMetadata *cachedMetadata = [self.dropboxFiles objectForKey:metadata.path];
    
    // File is the same, don't need to redownload
    if ([metadata.rev isEqualToString:cachedMetadata.rev])
    {
        return;
    }
    
    // Handle Upload History files differently than other files
    if ([[[metadata.path lowercaseString] stringByDeletingLastPathComponent] hasSuffix:@"upload history"] && [[[metadata.path pathExtension] lowercaseString] isEqualToString:@"plist"])
    {
        NSString *localPath = [[self uploadHistoryDirectoryPath] stringByAppendingPathComponent:metadata.filename];
        [self prepareToDownloadFileWithMetadata:metadata toPath:localPath fileType:GBADropboxFileTypeUploadHistory singleFile:NO];
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *romName = [self romNameFromDropboxPath:metadata.path];
    NSString *embeddedName = [self embededdROMNameFromDropboxPath:metadata.path];
    
    if (romName == nil) // ROM doesn't exist on device
    {
        DLog(@"ROM doesn't exist on device: %@", embeddedName);
        return;
    }
    
    if ([[[metadata.path pathExtension] lowercaseString] isEqualToString:@"sav"])
    {
        // Conflicted file, don't download
        if (![[metadata.filename stringByDeletingPathExtension] isEqualToString:embeddedName])
        {
            DLog(@"Aborting attempt to download conflicted/invalid file %@", metadata.filename);
            return;
        }
        
        GBAROM *rom = [GBAROM romWithName:romName];
        
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:rom.saveFileFilepath error:nil];
        NSDate *currentDate = [attributes fileModificationDate];
        NSDate *previousDate = cachedMetadata.lastModifiedDate;
        
        DLog(@"Previous Date: %@ Current Date: %@", previousDate, currentDate);
        
        // If current date is different than previous date, previous metadata exists, and ROM + save file exists, file is conflicted
        // We don't see which date is later in case the user messes with the date (which isn't unreasonable considering the distribution method)
        if (cachedMetadata && ![previousDate isEqual:currentDate] && [self romExistsWithName:rom.name] && [[NSFileManager defaultManager] fileExistsAtPath:rom.filepath isDirectory:nil])
        {
            DLog(@"Conflict downloading file: %@ Rev: %@ Cached Metadata: %@ New Metadata: %@", metadata.filename, metadata.rev, cachedMetadata.rev, metadata);
            
            [rom setConflicted:YES];
            [rom setSyncingDisabled:YES];
            return;
        }
        
#if !(TARGET_IPHONE_SIMULATOR)
        
        // Post notification if user is currently running ROM to be updated
        if ([[[[GBAEmulatorCore sharedCore] rom] name] isEqualToString:romName])
        {
            [rom setConflicted:YES];
            [rom setSyncingDisabled:YES];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:GBAHasUpdatedSaveForCurrentGameFromDropboxNotification object:[[GBAEmulatorCore sharedCore] rom]];
            
            return;
        }
        
#endif
        
        [self prepareToDownloadFileWithMetadata:metadata toPath:rom.saveFileFilepath fileType:GBADropboxFileTypeSave singleFile:NO];
    }
}

- (void)prepareToDownloadFileWithMetadata:(DBMetadata *)metadata toPath:(NSString *)localPath fileType:(GBADropboxFileType)fileType singleFile:(BOOL)singleFile
{
    NSDictionary *downloadDictionary = @{GBASyncingFileRevKey: metadata.rev, GBASyncingLocalPathKey: localPath, GBASyncingDropboxPathKey: metadata.path, GBASyncingFileTypeKey: @(fileType), GBASyncingSingleFileKey: @(singleFile)};
    [self.pendingDownloads setObject:downloadDictionary forKey:metadata.path];
    [self.pendingDownloads writeToFile:[self pendingDownloadsPath] atomically:YES];
}

- (void)downloadFileWithMetadata:(DBMetadata *)metadata toPath:(NSString *)path fileType:(GBADropboxFileType)fileType completionBlock:(GBASyncingCompletionBlock)completionBlock
{
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = rst_begin_background_task();
    
    self.syncingTaskCount++;
    
    [self prepareToDownloadFileWithMetadata:metadata toPath:path fileType:fileType singleFile:YES];
    
    // Won't be uploading, so remove it from pendingUploads
    [self.pendingUploads removeObjectForKey:path];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
    
    NSMutableDictionary *dictionary = [@{GBASyncingDropboxPathKey: metadata.path, GBASyncingLocalPathKey: path, GBASyncingBackgroundTaskIdentifierKey: @(backgroundTaskIdentifier)} mutableCopy];
    
    if (completionBlock)
    {
        dictionary[GBASyncingCompletionBlockKey] = [completionBlock copy];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.shouldShowSyncingStatus)
        {
            [RSTToastView showWithActivityMessage:@"Downloading..."];
        }
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    });
    
    [self.currentDownloads setObject:dictionary forKey:metadata.path];
    [self.restClient loadFile:metadata.path intoPath:path];
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)downloadedPath contentType:(NSString *)contentType metadata:(DBMetadata *)metadata
{
    DLog(@"Loaded File: %@", downloadedPath);
    
    // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
    NSDictionary *attributes = @{NSFileModificationDate: metadata.lastModifiedDate};
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:downloadedPath error:nil];
    
    [self.dropboxFiles setObject:metadata forKey:metadata.path];
    [NSKeyedArchiver archiveRootObject:self.dropboxFiles toFile:[self dropboxFilesPath]];
    
    [self.pendingDownloads removeObjectForKey:metadata.path];
    [self.pendingDownloads writeToFile:[self pendingDownloadsPath] atomically:YES];
    
    [self handleCompletedDownloadForFileAtDropboxPath:metadata.path withError:nil syncCompletionMessage:NSLocalizedString(@"Sync Complete!", @"")];
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error
{
    NSString *dropboxPath = [error userInfo][@"path"];
    
    NSString *message = NSLocalizedString(@"Sync Complete!", @"");
    
    if ([error code] == 404) // 404: File has been deleted (according to dropbox)
    {
        DLog(@"File doesn't exist for download...ignoring %@", [dropboxPath lastPathComponent]);
        
        [self.pendingDownloads removeObjectForKey:dropboxPath];
        [self.pendingDownloads writeToFile:[self pendingDownloadsPath] atomically:YES];
        
        [self handleCompletedDownloadForFileAtDropboxPath:dropboxPath withError:nil syncCompletionMessage:message];
        
        return;
    }
    
    NSDictionary *downloadDictionary = self.currentDownloads[dropboxPath];
    
    if ([downloadDictionary[GBASyncingSingleFileKey] boolValue])
    {
        message = NSLocalizedString(@"Download Failed", @"");
    }
    
    DLog(@"Failed to load file: %@ Error: %@", [dropboxPath lastPathComponent], [error userInfo]);
    
    [self handleCompletedDownloadForFileAtDropboxPath:dropboxPath withError:error syncCompletionMessage:message];
    
}

- (void)handleCompletedDownloadForFileAtDropboxPath:(NSString *)dropboxPath withError:(NSError *)error syncCompletionMessage:(NSString *)message
{
    if ([[self romNameFromDropboxPath:dropboxPath] isEqualToString:@"Upload History"])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:GBAUpdatedDeviceUploadHistoryNotification object:dropboxPath];
    }
    
    NSDictionary *downloadDictionary = self.currentDownloads[dropboxPath];
    GBASyncingCompletionBlock completionBlock = downloadDictionary[GBASyncingCompletionBlockKey];
    
    if (completionBlock)
    {
        completionBlock(downloadDictionary[GBASyncingLocalPathKey], dropboxPath, error);
    }
    
    if (downloadDictionary[GBASyncingBackgroundTaskIdentifierKey])
    {
        UIBackgroundTaskIdentifier identifier = [downloadDictionary[GBASyncingBackgroundTaskIdentifierKey] unsignedIntegerValue];
        rst_end_background_task(identifier);
    }
    
    [self.currentDownloads removeObjectForKey:dropboxPath];
    
    if ([self.currentDownloads count] == 0)
    {
        [self finishSyncingWithCompletionMessage:message duration:1];
    }
}

#pragma mark - Notifications

- (void)romConflictedStateDidChange:(NSNotification *)notification
{
    self.conflictedROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
}

- (void)romSyncingDisabledStateDidChange:(NSNotification *)notification
{
    self.syncingDisabledROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]];
}

- (void)dropboxLoggedOut:(NSNotification *)notification
{
    self.dropboxFiles = [NSMutableDictionary dictionary];
    self.conflictedROMs = [NSSet set];
    self.syncingDisabledROMs = [NSSet set];
    self.deviceUploadHistory = [NSMutableDictionary dictionary];
    self.pendingUploads = [NSMutableDictionary dictionary];
    self.pendingDownloads = [NSMutableDictionary dictionary];
    self.currentUploads = [NSMutableDictionary dictionary];
    self.currentDownloads = [NSMutableDictionary dictionary];
}

#pragma mark - Public

- (BOOL)isDownloadingDataForROM:(GBAROM *)rom
{
    // Use pendingDownloads, not currentDownloads, in case we check while we're uploading data but before we start actually downloading
    NSDictionary *pendingDownloads = [self.pendingDownloads copy];
    
    __block BOOL isDownloadingData = NO;
    
    [pendingDownloads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *dictionary, BOOL *stop) {
        NSString *dropboxPath = dictionary[GBASyncingDropboxPathKey];
        GBADropboxFileType fileType = (GBADropboxFileType)[dictionary[GBASyncingFileTypeKey] integerValue];
        
        if (fileType != GBADropboxFileTypeUploadHistory)
        {
            NSString *romName = [self romNameFromDropboxPath:dropboxPath];
            
            if ([romName isEqualToString:rom.name])
            {
                DLog(@"Rom Name: %@ Current Name: %@", romName, rom.name);
                isDownloadingData = YES;
            }
        }
    }];
    
    return isDownloadingData;
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

- (NSString *)embededdROMNameFromDropboxPath:(NSString *)dropboxPath
{
    NSArray *components = [dropboxPath pathComponents];
    if (components.count > 1)
    {
        return components[1];
    }
    
    return nil;
}

- (NSString *)romNameFromDropboxPath:(NSString *)dropboxPath
{
    NSString *embeddedROMName = [self embededdROMNameFromDropboxPath:dropboxPath];
    
    NSDictionary *cachedROMs = [NSDictionary dictionaryWithContentsOfFile:[self cachedROMsPath]];
    
    __block NSString *romName = nil;
    
    [cachedROMs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *embeddedName, BOOL *stop) {
        if ([embeddedROMName isEqualToString:embeddedName])
        {
            romName = key;
            *stop = YES;
        }
    }];
    
    if (romName == nil)
    {
        DLog(@"Aww shit: %@", dropboxPath);
    }
    
    return romName;
}

- (NSDictionary *)dropboxFilesFromDeltaEntries:(NSArray *)entries
{
    NSMutableDictionary *dropboxFiles = [NSMutableDictionary dictionary];
    
    for (DBDeltaEntry *entry in entries)
    {
        if ([entry.metadata isDeleted] || entry.metadata.path == nil || entry.metadata.filename == nil)
        {
            continue;
        }
        
        if ([entry.lowercasePath.pathExtension isEqualToString:@"sav"] || [entry.lowercasePath.pathExtension isEqualToString:@"plist"])
        {
            [dropboxFiles setObject:entry.metadata forKey:entry.metadata.path];
        }
        
    }
    
    return dropboxFiles;
}

- (NSString *)cachedROMsPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    return [libraryDirectory stringByAppendingPathComponent:@"cachedROMs.plist"];
}

#pragma mark - Filepaths

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

#pragma mark - Getters/Setters

- (BOOL)performedInitialSync
{
    NSDictionary *dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"initialSync"];
    return [dictionary[@"completed"] boolValue];
}

- (void)setShouldShowSyncingStatus:(BOOL)shouldShowSyncingStatus
{
    if (_shouldShowSyncingStatus == shouldShowSyncingStatus)
    {
        return;
    }
    
    _shouldShowSyncingStatus = shouldShowSyncingStatus;
    
    if (!shouldShowSyncingStatus)
    {
        [RSTToastView hide];
    }
    else if ([self isSyncing])
    {
        [RSTToastView show];
    }
    
}

- (BOOL)isSyncing
{
    return (self.syncingTaskCount > 0);
}

@end
