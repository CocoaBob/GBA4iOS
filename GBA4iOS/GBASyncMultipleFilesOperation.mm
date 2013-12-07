//
//  GBASyncMultipleFilesOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncMultipleFilesOperation_Private.h"
#import "GBASyncManager_Private.h"

NSString * const GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification = @"GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification";
NSString * const GBAUpdatedDeviceUploadHistoryNotification = @"GBAUpdatedDeviceUploadHistoryNotification";

@implementation GBASyncMultipleFilesOperation

#pragma mark - Initialization

- (instancetype)init
{
    self = [super init];
    
    if (self == nil)
    {
        return nil;
    }
    
    _uploadOperationQueue = ({
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.name = @"com.GBA4iOS.sync_multiple_files_upload_operation_queue";
        [operationQueue setMaxConcurrentOperationCount:1]; // So we can display info for each individual upload
        [operationQueue setSuspended:YES];
        operationQueue;
    });
    
    _downloadOperationQueue = ({
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.name = @"com.GBA4iOS.sync_multiple_files_download_operation_queue";
        [operationQueue setMaxConcurrentOperationCount:1]; // So we can display info for each individual download
        [operationQueue setSuspended:YES];
        operationQueue;
    });
    
    return self;
}

#pragma mark - Download Files

- (void)downloadFiles
{    
    NSSet *syncingDisabledROMs = [[GBASyncManager sharedManager] syncingDisabledROMs];
    NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    
    NSDictionary *pendingDownloads = [[[GBASyncManager sharedManager] pendingDownloads] copy];
    
    if ([pendingDownloads count] == 0)
    {
        [self uploadFiles];
        return;
    }
    
    RSTToastView *downloadingProgressToastView = [RSTToastView toastViewWithMessage:nil];
        
    [pendingDownloads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *downloadOperationDictionary, BOOL *stop) {
        
        GBASyncDownloadOperation *downloadOperation = [[GBASyncDownloadOperation alloc] initWithLocalPath:downloadOperationDictionary[GBASyncLocalPathKey]
                                                                                        dropboxPath:downloadOperationDictionary[GBASyncDropboxPathKey]
                                                                                           metadata:downloadOperationDictionary[GBASyncMetadataKey]];
        
        if ([[GBASyncManager uniqueROMNameFromDropboxPath:downloadOperation.dropboxPath] isEqualToString:@"Upload History"])
        {
            __weak GBASyncDownloadOperation *weakOperation = downloadOperation;
            downloadOperation.syncCompletionBlock = ^(NSString *localPath, DBMetadata *metadata, NSError *error) {
                if (error == nil)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:GBAUpdatedDeviceUploadHistoryNotification object:weakOperation.dropboxPath];
                    });
                }
            };
            
            [downloadOperation setQueuePriority:NSOperationQueuePriorityNormal];
            [self.downloadOperationQueue addOperation:downloadOperation];
            return;
        }
        
        NSString *romName = [GBASyncManager romNameFromDropboxPath:downloadOperation.dropboxPath];
        
        if (romName == nil)
        {
            return;
        }
        
        if ([syncingDisabledROMs containsObject:romName] || ![self romExistsWithName:romName])
        {
            return;
        }
        
        // ROM SAV file
        if ([[[downloadOperation.dropboxPath pathExtension] lowercaseString] isEqualToString:@"sav"])
        {
            DBMetadata *cachedMetadata = [dropboxFiles objectForKey:downloadOperation.dropboxPath];
            GBAROM *rom = [GBAROM romWithName:romName];
            
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:rom.saveFileFilepath error:nil];
            NSDate *currentDate = [attributes fileModificationDate];
            NSDate *previousDate = cachedMetadata.lastModifiedDate;
            
            // If current date is different than previous date, previous metadata exists, and ROM + save file exists, file is conflicted
            // We don't see which date is later in case the user messes with the date (which isn't unreasonable considering the distribution method)
            if (cachedMetadata && ![previousDate isEqual:currentDate] && [self romExistsWithName:rom.name] && [[NSFileManager defaultManager] fileExistsAtPath:rom.saveFileFilepath isDirectory:nil])
            {
                DLog(@"Conflict downloading file: %@ Cached Metadata: %@", [downloadOperation.dropboxPath lastPathComponent], cachedMetadata.rev);
                
                DLog(@"Old: %@ New: %@", previousDate, currentDate);
                
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
                
                [[NSNotificationCenter defaultCenter] postNotificationName:GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification object:[[GBAEmulatorCore sharedCore] rom]];
                
                return;
            }
            
#endif
        }
        
        downloadOperation.delegate = self;
        downloadOperation.toastView = downloadingProgressToastView;
        [downloadOperation setQueuePriority:NSOperationQueuePriorityNormal];
        [self.downloadOperationQueue addOperation:downloadOperation];
    }];
    
    
    [self.downloadOperationQueue setSuspended:NO];
    [self.downloadOperationQueue waitUntilAllOperationsAreFinished];
    [self.downloadOperationQueue setSuspended:YES];
    
    [self uploadFiles];
}

- (void)checkForMissingLocalFiles
{
    
}

- (void)prepareToDownloadFileWithMetadataIfNeeded:(DBMetadata *)metadata
{
    NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    DBMetadata *cachedMetadata = [dropboxFiles objectForKey:metadata.path];
    
    NSString *localPath = nil;
    
    // File is the same, don't need to redownload
    if ([metadata.rev isEqualToString:cachedMetadata.rev])
    {
        return;
    }
    
    NSString *romName = [GBASyncManager romNameFromDropboxPath:metadata.path];
    NSString *uniqueName = [GBASyncManager uniqueROMNameFromDropboxPath:metadata.path];
        
    if (romName == nil && ![uniqueName isEqualToString:@"Upload History"]) // ROM doesn't exist on device
    {
        // Logs warning in [self uniqueROMNameFromDropboxPath:]
        return;
    }
    
    // ROM SAV files
    if ([[[metadata.path pathExtension] lowercaseString] isEqualToString:@"sav"])
    {
        // Conflicted file, don't download
        if (![[metadata.filename stringByDeletingPathExtension] isEqualToString:uniqueName])
        {
            DLog(@"Aborting attempt to download conflicted/invalid file %@", metadata.filename);
            return;
        }
        
        GBAROM *rom = [GBAROM romWithName:romName];
        localPath = rom.saveFileFilepath;
    }
    else if ([uniqueName isEqualToString:@"Upload History"] && [[[metadata.path pathExtension] lowercaseString] isEqualToString:@"plist"])
    {
        localPath = [[[GBASyncManager currentDeviceUploadHistoryPath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:metadata.filename];
    }
    
    // Use dropbox path because we want the latest version possible, and supplying metadata locks it to a certain revision
    // GBASyncDownloadOperation *downloadOperation = [[GBASyncDownloadOperation alloc] initWithLocalPath:localPath metadata:metadata];
    
    // Cache it to pendingDownloads
    GBASyncDownloadOperation *downloadOperation = [[GBASyncDownloadOperation alloc] initWithLocalPath:localPath dropboxPath:metadata.path];
    [[GBASyncManager sharedManager] cacheDownloadOperation:downloadOperation];
}

#pragma mark - Upload Files

- (void)uploadFiles
{
    NSSet *syncingDisabledROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[GBASyncManager syncingDisabledROMsPath]]];
    
    NSDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
            
    if ([pendingUploads count] == 0)
    {
        [self finishSync]; // No need to update upload history, since there were no files to upload
        return;
    }
    
    DLog(@"%@", syncingDisabledROMs);
    
    RSTToastView *uploadingProgressToastView = [RSTToastView toastViewWithMessage:nil];
    
    __block NSMutableArray *filteredOperations = [NSMutableArray array];
    
    [pendingUploads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *uploadOperationDictionary, BOOL *stop) {
        
        GBASyncUploadOperation *uploadOperation = [[GBASyncUploadOperation alloc] initWithLocalPath:uploadOperationDictionary[GBASyncLocalPathKey]
                                                                                        dropboxPath:uploadOperationDictionary[GBASyncDropboxPathKey]
                                                                                           metadata:uploadOperationDictionary[GBASyncMetadataKey]];
        
        if ([[GBASyncManager uniqueROMNameFromDropboxPath:uploadOperation.dropboxPath] isEqualToString:@"Upload History"])
        {
            [uploadOperation setQueuePriority:NSOperationQueuePriorityNormal];
            [self.uploadOperationQueue addOperation:uploadOperation];
            return;
        }
        
        NSString *romName = [GBASyncManager romNameFromDropboxPath:uploadOperation.dropboxPath];
        
        if ([syncingDisabledROMs containsObject:romName])
        {
            DLog(@"Syncing turned off for ROM: %@", romName);
            return;
        }
        else
        {
            DLog(@"ROMNAME: %@", romName);
        }
            
        uploadOperation.delegate = self;
        uploadOperation.toastView = uploadingProgressToastView;
        [uploadOperation setQueuePriority:NSOperationQueuePriorityNormal];
        [self.uploadOperationQueue addOperation:uploadOperation];
        
        // Don't add if it's only an upload history operation
        [filteredOperations addObject:uploadOperation];
    }];
    
    GBASyncUploadOperation *uploadOperation = [filteredOperations lastObject];
    uploadOperation.updatesDeviceUploadHistoryUponCompletion = YES;
    
    filteredOperations = nil;
    
    // If there are no opertions, this will do nothing, but we do it in case there's only device upload history operations which aren't included in operationCount
    [self.uploadOperationQueue setSuspended:NO];
    [self.uploadOperationQueue waitUntilAllOperationsAreFinished];
    [self.uploadOperationQueue setSuspended:YES];
    
    [self finishSync];
}

- (void)prepareToUploadFilesMissingFromDropboxFilesAndConflictIfNeeded:(BOOL)conflictIfNeeded
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
    NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        NSString *filepath = [documentsDirectory stringByAppendingPathComponent:filename];
        
        // Only upload SAV files
        if (![[[filename pathExtension] lowercaseString] isEqualToString:@"sav"])
        {
            continue;
        }
        
        NSString *romName = [filename stringByDeletingPathExtension];
        GBAROM *rom = [GBAROM romWithName:romName];
        
        // ROM doesn't exist, don't upload
        if (rom == nil)
        {
            continue;
        }
        
        NSString *uniqueName = [rom uniqueName];
        NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@.sav", uniqueName, uniqueName];
        
        // Already marked for upload, don't need to upload again
        if (pendingUploads[filepath])
        {
            continue;
        }
        
        DBMetadata *dropboxMetadata = dropboxFiles[dropboxPath];
        
        if (dropboxMetadata)
        {
            if (conflictIfNeeded)
            {
                DLog(@"Conflicted ROM: %@ Dropbox Rev: %@", romName, dropboxMetadata.rev);
                
                [rom setConflicted:YES];
                [rom setSyncingDisabled:YES];
            }
            
            continue;
        }
        
        // Cache it to pendingUploads
        GBASyncUploadOperation *uploadOperation = [[GBASyncUploadOperation alloc] initWithLocalPath:rom.saveFileFilepath dropboxPath:dropboxPath];
        [[GBASyncManager sharedManager] cacheUploadOperation:uploadOperation];
    }
    
    [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
}

#pragma mark - Finish Sync

- (void)finishSync
{
    [self finish];
}

#pragma mark GBASyncOperationDelegate

- (BOOL)syncOperation:(GBASyncOperation *)syncOperation shouldShowToastView:(RSTToastView *)toastView
{
    return [self.delegate syncOperation:self shouldShowToastView:toastView];
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

- (NSDictionary *)validDropboxFilesFromDeltaEntries:(NSArray *)entries
{
    NSMutableDictionary *dropboxFiles = [NSMutableDictionary dictionary];
    
    for (DBDeltaEntry *entry in entries)
    {
        // If deleted, remove it from dropbox files
        if ([entry.metadata isDeleted] || entry.metadata.path == nil || entry.metadata.filename == nil)
        {
            NSDictionary *cachedDropboxFiles = [[[GBASyncManager sharedManager] dropboxFiles] copy];
            
            for (NSString *key in cachedDropboxFiles)
            {
                if ([[key lowercaseString] isEqualToString:entry.lowercasePath])
                {
                    [[[GBASyncManager sharedManager] dropboxFiles] removeObjectForKey:key];
                }
            }
            
            [NSKeyedArchiver archiveRootObject:[[GBASyncManager sharedManager] dropboxFiles] toFile:[GBASyncManager dropboxFilesPath]];
            
            continue;
        }
        
        if ([entry.lowercasePath.pathExtension isEqualToString:@"sav"] || [entry.lowercasePath.pathExtension isEqualToString:@"plist"])
        {
            [dropboxFiles setObject:entry.metadata forKey:entry.metadata.path];
        }
        
    }
    
    return dropboxFiles;
}


@end
