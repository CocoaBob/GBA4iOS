//
//  GBASyncMultipleFilesOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncMultipleFilesOperation_Private.h"
#import "GBASyncManager_Private.h"

#import "SSZipArchive.h"

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
    
    _movingOperationQueue = ({
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.name = @"com.GBA4iOS.sync_multiple_files_renaming_operation_queue";
        [operationQueue setMaxConcurrentOperationCount:1];
        [operationQueue setSuspended:YES];
        operationQueue;
    });
    
    _deletionOperationQueue = ({
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.name = @"com.GBA4iOS.sync_multiple_files_deletion_operation_queue";
        [operationQueue setMaxConcurrentOperationCount:1];
        [operationQueue setSuspended:YES];
        operationQueue;
    });
    
    return self;
}

#pragma mark - Syncing

- (void)beginSyncOperation
{
    [self showToastViewWithMessage:NSLocalizedString(@"Syncing…", @"") forDuration:0 showActivityIndicator:YES];
}

#pragma mark - Renaming Files

- (void)moveFiles
{
    NSSet *syncingDisabledROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[GBASyncManager syncingDisabledROMsPath]]];
    
    rst_dispatch_sync_on_main_thread(^{
        self.dropboxStatusToastView = [RSTToastView toastViewWithMessage:nil];
    });
    
    NSDictionary *pendingMoves = [[[GBASyncManager sharedManager] pendingMoves] copy];
    NSMutableDictionary *pendingDeletions = [[GBASyncManager sharedManager] pendingDeletions];
    
    if ([pendingMoves count] == 0)
    {
        [self downloadFiles]; // No need to update upload history, since there were no files to upload
        return;
    }
    
    [pendingMoves enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *moveOperationDictionary, BOOL *stop) {
        
        GBASyncMoveOperation *moveOperation = [[GBASyncMoveOperation alloc] initWithDropboxPath:moveOperationDictionary[GBASyncDropboxPathKey]
                                                                                destinationPath:moveOperationDictionary[GBASyncDestinationPathKey]];
        
        NSString *romName = [GBASyncManager romNameFromDropboxPath:moveOperation.dropboxPath];
        
        // If we're the ones moving it, I'm willing to bet it was before we deleted the file
        /* if (pendingDeletions[moveOperation.dropboxPath])
        {
            [pendingDeletions removeObjectForKey:moveOperation.dropboxPath];
            [pendingDeletions writeToFile:[GBASyncManager pendingDeletionsPath] atomically:YES];
        }*/
        
        if ([syncingDisabledROMs containsObject:romName])
        {
            //DLog(@"Syncing turned off for ROM and renaming operations: %@", romName);
            return;
        }
        
        moveOperation.delegate = self;
        
        [self.movingOperationQueue addOperation:moveOperation];
    }];
    
    if ([self.movingOperationQueue operationCount] > 0)
    {
        rst_dispatch_sync_on_main_thread(^{
            self.toastView = [RSTToastView toastViewWithMessage:nil];
        });
        
        GBASyncMoveOperation *operation = [[self.movingOperationQueue operations] lastObject];
        operation.updatesDeviceUploadHistoryUponCompletion = YES;
        [self showToastViewWithMessage:NSLocalizedString(@"Updating Dropbox…", @"") forDuration:0 showActivityIndicator:YES];
    }
    
    [self.movingOperationQueue setSuspended:NO];
    [self.movingOperationQueue waitUntilAllOperationsAreFinished];
    [self.movingOperationQueue setSuspended:YES];
    
    [self downloadFiles];
}

#pragma mark - Download Files

- (void)downloadFiles
{    
    NSSet *syncingDisabledROMs = [[GBASyncManager sharedManager] syncingDisabledROMs];
    NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    NSMutableDictionary *pendingDeletions = [[GBASyncManager sharedManager] pendingDeletions];
    NSMutableDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
    
    NSDictionary *pendingDownloads = [[[GBASyncManager sharedManager] pendingDownloads] copy];
    
    if ([pendingDownloads count] == 0)
    {
        [self uploadFiles];
        return;
    }
        
    __block RSTToastView *downloadingProgressToastView = nil;
    
    rst_dispatch_sync_on_main_thread(^{
        downloadingProgressToastView = [RSTToastView toastViewWithMessage:nil];
    });
    
    NSMutableArray *operations = [NSMutableArray array];
        
    [pendingDownloads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *downloadOperationDictionary, BOOL *stop) {
        
        NSString *dropboxPath = downloadOperationDictionary[GBASyncDropboxPathKey];
        NSString *localPath = [GBASyncManager localPathForDropboxPath:dropboxPath uploading:NO];
        DBFILESMetadata *metadata = downloadOperationDictionary[GBASyncMetadataKey];
        
        GBASyncDownloadOperation *downloadOperation = [[GBASyncDownloadOperation alloc] initWithDropboxPath:dropboxPath
                                                                                           metadata:metadata];
        
        if ([[GBASyncManager uniqueROMNameFromDropboxPath:downloadOperation.dropboxPath] isEqualToString:@"Upload History"])
        {
            __weak GBASyncDownloadOperation *weakOperation = downloadOperation;
            downloadOperation.syncCompletionBlock = ^(NSString *localPath, DBFILESMetadata *metadata, NSError *error) {
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
        
        // Wait until it finishes moving before uploading
        if ([[GBASyncManager sharedManager] pendingMoveToOrFromDropboxPath:downloadOperation.dropboxPath])
        {
            return;
        }
        
        // It's been updated, so ignore our pending deletion (better have to delete a second time than lose data)
        if (pendingDeletions[downloadOperation.dropboxPath])
        {
            [pendingDeletions removeObjectForKey:downloadOperation.dropboxPath];
            [pendingDeletions writeToFile:[GBASyncManager pendingDeletionsPath] atomically:YES];
        }
        
        NSString *dropboxPathExtension = [[downloadOperation.dropboxPath pathExtension] lowercaseString];
        
        // ROM Save files. Because there's only one save file ever allowed at one time, we have to be extra careful. Otherwise, we don't care if we overwrite local with whatever the new server is.
        if ([dropboxPathExtension isEqualToString:@"sav"] || [dropboxPathExtension isEqualToString:@"rtcsav"])
        {
            GBAROM *rom = [GBAROM romWithName:romName];
            
            if (([dropboxPathExtension isEqualToString:@"sav"] && [rom usesGBCRTC]) || ([dropboxPathExtension isEqualToString:@"rtcsav"] && ![rom usesGBCRTC]))
            {
                // Attempting to download wrong file type for ROM, so abort it.
                
                [[[GBASyncManager sharedManager] pendingDownloads] removeObjectForKey:downloadOperation.dropboxPath];
                [NSKeyedArchiver archiveRootObject:[[GBASyncManager sharedManager] pendingDownloads] toFile:[GBASyncManager pendingDownloadsPath]];
                
                return;
            }
            
            DBFILESMetadata *cachedMetadata = [dropboxFiles objectForKey:downloadOperation.dropboxPath];
            DBFILESFileMetadata *cachedFileMetadata = (DBFILESFileMetadata *)cachedMetadata;
            
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:rom.saveFileFilepath error:nil];
            NSDate *currentDate = [attributes fileModificationDate];
            NSDate *previousDate = cachedFileMetadata.serverModified;
            
            // If current date is different than previous date, previous metadata exists, and ROM + save file exists, file is conflicted
            // We don't see which date is later in case the user messes with the date (which isn't unreasonable considering the distribution method)
            if (cachedMetadata && ![previousDate isEqual:currentDate] && [self romExistsWithName:rom.name] && [[NSFileManager defaultManager] fileExistsAtPath:rom.saveFileFilepath])
            {
                DLog(@"Conflict downloading file: %@ Cached Metadata: %@", [downloadOperation.dropboxPath lastPathComponent], cachedFileMetadata.rev);
                
                [rom setConflicted:YES];
                [rom setSyncingDisabled:YES];
                return;
            }
            
            
            // Post notification if user is currently running ROM to be updated
            if ([[[[GBAEmulatorCore sharedCore] rom] name] isEqualToString:romName])
            {
                [rom setConflicted:YES];
                [rom setSyncingDisabled:YES];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification object:[[GBAEmulatorCore sharedCore] rom]];
                
                return;
            }
        }
        else
        {
            // This will really only ever happen with cheats, so we make sure to delete it from pending uploads since we're now downloading it instead.
            
            NSString *relativePath = [GBASyncManager relativePathForLocalPath:localPath];
            
            if (pendingUploads[relativePath])
            {
                [[GBASyncManager sharedManager] removeCachedUploadOperationForRelativePath:relativePath];
                [NSKeyedArchiver archiveRootObject:pendingUploads toFile:[GBASyncManager pendingUploadsPath]];
            }
        }
        
        downloadOperation.delegate = self;
        downloadOperation.toastView = downloadingProgressToastView;
        [downloadOperation setQueuePriority:NSOperationQueuePriorityNormal];
        [operations addObject:downloadOperation];
    }];
    
    [operations sortUsingComparator:[self sortedDropboxOperationsComparator]];
    
    [self.downloadOperationQueue setSuspended:NO];
    [self.downloadOperationQueue addOperations:operations waitUntilFinished:YES];
    [self.downloadOperationQueue setSuspended:YES];
    
    [self uploadFiles];
}

- (void)prepareToDownloadFileWithMetadataIfNeeded:(DBFILESMetadata *)metadata isDeltaChange:(BOOL)deltaChange
{
    DLog(@"Metadata: %@", metadata);
    NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    DBFILESMetadata *cachedMetadata = [dropboxFiles objectForKey:metadata.pathLower];
    
    NSString *romName = [GBASyncManager romNameFromDropboxPath:metadata.pathLower];
    NSString *uniqueName = [GBASyncManager uniqueROMNameFromDropboxPath:metadata.pathLower];
    
    NSArray *pathComponents = [metadata.pathLower pathComponents];
    
    if ([pathComponents count] < 2)
    {
        return;
    }
    
    if ([pathComponents count] < 4 && ![pathComponents[1] isEqualToString:@"Upload History"])
    {
        return;
    }
    
    NSString *directory = pathComponents[2];
        
    GBAROM *rom = [GBAROM romWithName:romName];
    
    if ([directory isEqualToString:@"Saves"]) // ROM save files
    {
        // Only .sav/.rtcsav files
        if (!([[[metadata.pathLower pathExtension] lowercaseString] isEqualToString:@"sav"] || [[[metadata.pathLower pathExtension] lowercaseString] isEqualToString:@"rtcsav"]))
        {
            return;
        }
        
        // Conflicted file, don't download
        if (![[((DBFILESFileMetadata *)metadata).name stringByDeletingPathExtension] isEqualToString:uniqueName])
        {
            //DLog(@"Aborting attempt to download conflicted/invalid file %@", metadata.filename);
            return;
        }
    }
    else if ([directory isEqualToString:@"Save States"]) // Save States
    {
        // Only .sgm files
        if (![[[metadata.pathLower pathExtension] lowercaseString] isEqualToString:@"sgm"])
        {
            return;
        }
    }
    else if ([directory isEqualToString:@"Cheats"]) // Cheats
    {
        // Only .gbacheat files
        if (![[[metadata.pathLower pathExtension] lowercaseString] isEqualToString:@"gbacheat"])
        {
            return;
        }
    }
    else if ([pathComponents[1] isEqualToString:@"Upload History"]) // Upload History
    {
        if (![[[metadata.pathLower pathExtension] lowercaseString] isEqualToString:@"plist"])
        {
            return;
        }
    }
    
    NSString *localPath = [GBASyncManager localPathForDropboxPath:metadata.pathLower uploading:NO];
    
    NSString *existingFileLocalPath = localPath;
    
    if ([localPath.pathExtension isEqualToString:@"rtcsav"])
    {
        existingFileLocalPath = rom.saveFileFilepath;
    }
    
    // Very important below block of code remains commented out, since you'll probably want to implement it again.
    // We need to make sure we have the download pending, even if the rom doesn't exist on device. Why? So that way we don't accidentally upload a new save when the user *does* download it
    /*
    if (romName == nil && ![uniqueName isEqualToString:@"Upload History"]) // ROM doesn't exist on device
    {
        // Logs warning in [self uniqueROMNameFromDropboxPath:]
        return;
    }*/
        
    // File is the same, and it exists, so no need to redownload
    if ([((DBFILESFileMetadata *)metadata).rev isEqualToString:((DBFILESFileMetadata *)cachedMetadata).rev] && [[NSFileManager defaultManager] fileExistsAtPath:existingFileLocalPath isDirectory:nil])
    {
        return;
    }
    
    NSMutableDictionary *pendingDeletions = [[GBASyncManager sharedManager] pendingDeletions];
    
    if (pendingDeletions[metadata.pathLower])
    {
        // Has been changed on server, ignore deletion
        if (deltaChange && ![((DBFILESFileMetadata *)metadata).rev isEqualToString:((DBFILESFileMetadata *)cachedMetadata).rev])
        {
            [pendingDeletions removeObjectForKey:metadata.pathLower];
            [pendingDeletions writeToFile:[GBASyncManager pendingDeletionsPath] atomically:YES];
        }
        else
        {
            // Continue to delete it, don't download files
            return;
        }
    }
    
    // Use dropbox path because we want the latest version possible, and supplying metadata locks it to a certain revision
    // GBASyncDownloadOperation *downloadOperation = [[GBASyncDownloadOperation alloc] initWithLocalPath:localPath metadata:metadata];
    
    // Cache it to pendingDownloads
    GBASyncDownloadOperation *downloadOperation = [[GBASyncDownloadOperation alloc] initWithDropboxPath:metadata.pathLower];
    [[GBASyncManager sharedManager] cacheDownloadOperation:downloadOperation];
}

#pragma mark - Upload Files

- (void)uploadFiles
{
    NSSet *syncingDisabledROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[GBASyncManager syncingDisabledROMsPath]]];
    
    NSDictionary *pendingUploads = [[[GBASyncManager sharedManager] pendingUploads] copy];
    NSMutableDictionary *pendingDeletions = [[GBASyncManager sharedManager] pendingDeletions];
        
    if ([pendingUploads count] == 0)
    {
        [self deleteFiles]; // No need to update upload history, since there were no files to upload
        return;
    }
    
    __block RSTToastView *uploadingProgressToastView = nil;
    
    rst_dispatch_sync_on_main_thread(^{
        uploadingProgressToastView = [RSTToastView toastViewWithMessage:nil];
    });
    
    NSMutableArray *operations = [NSMutableArray array];
    
    [pendingUploads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *uploadOperationDictionary, BOOL *stop) {
        
        NSString *dropboxPath = uploadOperationDictionary[GBASyncDropboxPathKey];
        NSString *localPath = [GBASyncManager localPathForDropboxPath:dropboxPath uploading:YES];
        
        DBFILESMetadata *metadata = uploadOperationDictionary[GBASyncMetadataKey];
        
        GBASyncUploadOperation *uploadOperation = [[GBASyncUploadOperation alloc] initWithDropboxPath:dropboxPath
                                                                                           metadata:metadata];
        
        if ([[GBASyncManager uniqueROMNameFromDropboxPath:uploadOperation.dropboxPath] isEqualToString:@"Upload History"])
        {
            [uploadOperation setQueuePriority:NSOperationQueuePriorityNormal];
            [self.uploadOperationQueue addOperation:uploadOperation];
            return;
        }
        
        // Always good to check, but it also is important so we don't remove from pendingDeletions when the file doesn't even exist to re-upload
        if (![[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:nil])
        {
            return;
        }
        
        NSString *romName = [GBASyncManager romNameFromDropboxPath:uploadOperation.dropboxPath];
        
        // It's been updated, so ignore our pending deletion (better have to delete a second time than lose data)
        // Yes, keep this. Other code relies on uploads taking precedence over deletions
        if (pendingDeletions[uploadOperation.dropboxPath])
        {
            [pendingDeletions removeObjectForKey:uploadOperation.dropboxPath];
            [pendingDeletions writeToFile:[GBASyncManager pendingDeletionsPath] atomically:YES];
        }
        
        if ([syncingDisabledROMs containsObject:romName])
        {
            //DLog(@"Syncing turned off for ROM: %@", romName);
            return;
        }
        
        if ([localPath.pathExtension isEqualToString:@"rtcsav"])
        {
            GBAROM *rom = [GBAROM romWithName:romName];
            
            // Below code is same as in -[GBASyncingDetailViewController syncWithDropbox]
            
            if (!([[NSFileManager defaultManager] fileExistsAtPath:rom.saveFileFilepath] && [[NSFileManager defaultManager] fileExistsAtPath:rom.rtcFileFilepath]))
            {
                // Both files should exist for us to continue
                return;
            }
            
            // Make sure no previous files remain there
            [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
            
            [SSZipArchive createZipFileAtPath:localPath withFilesAtPaths:@[rom.saveFileFilepath, rom.rtcFileFilepath]];
        }
            
        uploadOperation.delegate = self;
        uploadOperation.toastView = uploadingProgressToastView;
        [uploadOperation setQueuePriority:NSOperationQueuePriorityNormal];
        [operations addObject:uploadOperation];
    }];
    
    [operations sortUsingComparator:[self sortedDropboxOperationsComparator]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"class == %@", [GBASyncUploadOperation class]];
    GBASyncUploadOperation *uploadOperation = [[operations filteredArrayUsingPredicate:predicate] lastObject];
    uploadOperation.updatesDeviceUploadHistoryUponCompletion = YES;
    
    // If there are no opertions, this will do nothing, but we do it in case there's only device upload history operations which aren't included in operationCount
    [self.uploadOperationQueue setSuspended:NO];
    [self.uploadOperationQueue addOperations:operations waitUntilFinished:YES];
    [self.uploadOperationQueue setSuspended:YES];
    
    [self deleteFiles];
}

- (void)prepareToUploadFilesMissingFromDropboxFilesAndConflictIfNeeded:(BOOL)conflictIfNeeded
{
    [self prepareToUploadSavesMissingFromDropboxFilesAndConflictIfNeeded:conflictIfNeeded];
    [self prepareToUploadCheatsMissingFromDropboxFiles];
    [self prepareToUploadSaveStatesMissingFromDropboxFiles];
}

- (void)prepareToUploadSavesMissingFromDropboxFilesAndConflictIfNeeded:(BOOL)conflictIfNeeded
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
    NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        if (![[filename pathExtension] isEqualToString:@"sav"])
        {
            continue;
        }
        
        NSString *filepath = [documentsDirectory stringByAppendingPathComponent:filename];
        
        NSString *romName = [filename stringByDeletingPathExtension];
        GBAROM *rom = [GBAROM romWithName:romName];
        
        // ROM doesn't exist, don't upload
        if (rom == nil)
        {
            continue;
        }
        
        NSString *uniqueName = [rom uniqueName];
        NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@.sav", uniqueName, uniqueName];
        
        if ([rom usesGBCRTC])
        {
            dropboxPath = [GBASyncManager zippedDropboxPathForSaveFileDropboxPath:dropboxPath];
        }
        
        // Already marked for upload, don't need to upload again
        if (pendingUploads[[GBASyncManager relativePathForLocalPath:filepath]])
        {
            continue;
        }
        
        DBFILESMetadata *dropboxMetadata = dropboxFiles[dropboxPath];
        
        if (dropboxMetadata)
        {
            if (conflictIfNeeded)
            {
                DLog(@"Conflicted ROM: %@ Dropbox Rev: %@", romName, ((DBFILESFileMetadata *)dropboxMetadata).rev);
                
                [rom setConflicted:YES];
                [rom setSyncingDisabled:YES];
            }
            
            continue;
        }
        
        [[GBASyncManager sharedManager] prepareToUploadSaveFileForROM:rom];
    }
}

- (void)prepareToUploadCheatsMissingFromDropboxFiles
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
    NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    
    NSString *cheatsParentDirectory = [documentsDirectory stringByAppendingPathComponent:@"Cheats"];
    
    // NSDirectoryEnumerator raises exception if URL is nil
    if (![[NSFileManager defaultManager] fileExistsAtPath:cheatsParentDirectory isDirectory:nil])
    {
        return;
    }
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:cheatsParentDirectory]
                                                             includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler:^BOOL(NSURL *url, NSError *error)
                                         {
                                             NSLog(@"[Error] %@ (%@)", error, url);
                                             return YES;
                                         }];
    
    for (NSURL *fileURL in enumerator)
    {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        
        if (![isDirectory boolValue])
        {
            if (![[filename pathExtension] isEqualToString:@"gbacheat"])
            {
                continue;
            }
            
            NSString *filepath = [fileURL path];
            filepath = [filepath stringByReplacingOccurrencesOfString:@"/private/var/mobile" withString:@"/var/mobile"];
            NSString *romName = [[filepath stringByDeletingLastPathComponent] lastPathComponent];
            
            GBAROM *rom = [GBAROM romWithName:romName];
            
            // ROM doesn't exist, don't upload
            if (rom == nil)
            {
                continue;
            }
            
            NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Cheats/%@", rom.uniqueName, filename];
            
            // Already marked for upload, don't need to upload again
            if (pendingUploads[[GBASyncManager relativePathForLocalPath:filepath]])
            {
                continue;
            }
            
            // File exists on server, don't upload
            if (dropboxFiles[dropboxPath])
            {
                continue;
            }
                        
            // Wait until it finishes moving before uploading
            if ([[GBASyncManager sharedManager] pendingMoveToOrFromDropboxPath:dropboxPath])
            {
                continue;
            }
            
            GBACheat *cheat = [GBACheat cheatWithContentsOfFile:filepath];
            
            [[GBASyncManager sharedManager] prepareToUploadCheat:cheat forROM:rom];
        }
        
    }
}

- (void)prepareToUploadSaveStatesMissingFromDropboxFiles
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
    NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    
    NSString *saveStatesParentDirectory = [documentsDirectory stringByAppendingPathComponent:@"Save States"];
    
    // NSDirectoryEnumerator raises exception if URL is nil
    if (![[NSFileManager defaultManager] fileExistsAtPath:saveStatesParentDirectory isDirectory:nil])
    {
        return;
    }
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:saveStatesParentDirectory isDirectory:YES]
                                                             includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler:^BOOL(NSURL *url, NSError *error)
                                         {
                                             NSLog(@"[Error] %@ (%@)", error, url);
                                             return YES;
                                         }];
    
    for (NSURL *fileURL in enumerator)
    {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        
        if (![isDirectory boolValue])
        {
            if (![[[filename pathExtension] lowercaseString] isEqualToString:@"sgm"])
            {
                continue;
            }
            
            // Don't sync autosaves
            if ([[filename lowercaseString] isEqualToString:@"autosave.sgm"])
            {
                continue;
            }
            
            NSString *filepath = [fileURL path];
            filepath = [filepath stringByReplacingOccurrencesOfString:@"/private/var/mobile" withString:@"/var/mobile"];
            
            NSString *romName = [[filepath stringByDeletingLastPathComponent] lastPathComponent];
            
            GBAROM *rom = [GBAROM romWithName:romName];
            
            // ROM doesn't exist, don't upload
            if (rom == nil)
            {
                continue;
            }
            
            NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Save States/%@", rom.uniqueName, filename];
            
            // Already marked for upload, don't need to upload again
            if (pendingUploads[[GBASyncManager relativePathForLocalPath:filepath]])
            {
                continue;
            }
            
            // File exists on server, don't upload
            if (dropboxFiles[dropboxPath])
            {
                continue;
            }
                        
            // Wait until it finishes moving before uploading
            if ([[GBASyncManager sharedManager] pendingMoveToOrFromDropboxPath:dropboxPath])
            {
                continue;
            }
            
            [[GBASyncManager sharedManager] prepareToUploadSaveStateAtPath:filepath forROM:rom];
        }
        
    }
}

#pragma mark - Delete Files

- (void)deleteFiles
{
    NSSet *syncingDisabledROMs = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:[GBASyncManager syncingDisabledROMsPath]]];
    
    NSMutableDictionary *pendingDeletions = [[[GBASyncManager sharedManager] pendingDeletions] mutableCopy];
    
    if ([pendingDeletions count] == 0)
    {
        [self finishSync];
        return;
    }
    
    [pendingDeletions enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *deletionOperationDictionary, BOOL *stop) {
        GBASyncDeleteOperation *deleteOperation = [[GBASyncDeleteOperation alloc] initWithDropboxPath:deletionOperationDictionary[GBASyncDropboxPathKey]];
        
        NSString *romName = [GBASyncManager romNameFromDropboxPath:deleteOperation.dropboxPath];
        
        if ([syncingDisabledROMs containsObject:romName])
        {
            //DLog(@"Syncing turned off for ROM and deletions: %@", romName);
            return;
        }
        
        deleteOperation.delegate = self;
        [self.deletionOperationQueue addOperation:deleteOperation];
    }];
    
    if ([self.deletionOperationQueue operationCount] > 0)
    {
        rst_dispatch_sync_on_main_thread(^{
            self.toastView = [RSTToastView toastViewWithMessage:nil];
        });
        [self showToastViewWithMessage:NSLocalizedString(@"Updating Dropbox…", @"") forDuration:0 showActivityIndicator:YES];
    }
    
    [self.deletionOperationQueue setSuspended:NO];
    [self.deletionOperationQueue waitUntilAllOperationsAreFinished];
    [self.deletionOperationQueue setSuspended:YES];
    
    [self finishSync];
}

#pragma mark - Finish Sync

- (void)finishSync
{
    [self finish];
}

#pragma mark - GBASyncOperationDelegate

- (BOOL)syncOperation:(GBASyncOperation *)syncOperation shouldShowToastView:(RSTToastView *)toastView
{
    return [self.delegate syncOperation:self shouldShowToastView:toastView];
}

#pragma mark - Helper Methods

- (NSComparator)sortedDropboxOperationsComparator
{
    NSComparator comparator = ^(GBASyncFileOperation *a, GBASyncFileOperation *b) {
        NSString *uniqueNameA = [[a.dropboxPath pathComponents][1] lowercaseString];
        NSString *uniqueNameB = [[b.dropboxPath pathComponents][1] lowercaseString];
        
        // Keep files for same ROM together
        if (![uniqueNameA isEqualToString:uniqueNameB])
        {
            return [uniqueNameA compare:uniqueNameB];
        }
        
        // For safety
        if (a.dropboxPath.pathComponents.count < 3)
        {
            return NSOrderedDescending;
        }
        
        if (b.dropboxPath.pathComponents.count < 3)
        {
            return NSOrderedAscending;
        }
        
        // Upload saves, then save states, then cheats.
        
        NSString *subdirectoryA = [[a.dropboxPath pathComponents][2] lowercaseString];
        NSString *subdirectoryB = [[b.dropboxPath pathComponents][2] lowercaseString];
        
        BOOL subdirectoryAIsSaves = [subdirectoryA isEqualToString:@"saves"];
        BOOL subdirectoryBIsSaves = [subdirectoryB isEqualToString:@"saves"];
        
        // If either are saves, then we need to find out which one is saves, and make it first. Or, if they're both saves, then return normal comparison
        if (subdirectoryAIsSaves || subdirectoryBIsSaves)
        {
            if (subdirectoryAIsSaves && subdirectoryBIsSaves)
            {
                return [subdirectoryA compare:subdirectoryB];
            }
            
            if (subdirectoryAIsSaves)
            {
                return NSOrderedAscending;
            }
            
            if (subdirectoryBIsSaves)
            {
                return NSOrderedDescending;
            }
        }
        
        // Cheats is reverse alphabetical order from save states, so just flip order of comparators and return result.
        return [subdirectoryB compare:subdirectoryA];
    };
    
    return comparator;
}

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

- (NSDictionary *)validDropboxFilesFromDeltaEntries:(NSArray *)entries deleteDeletedDropboxFiles:(BOOL)deleteDeletedDropboxFiles
{
    NSMutableDictionary *dropboxFiles = [NSMutableDictionary dictionary];
    
    for (DBFILESMetadata *entry in entries)
    {
        // If deleted, remove it from dropbox files
        if ([entry isKindOfClass:DBFILESDeletedMetadata.class] || entry.pathLower == nil || ((DBFILESFileMetadata *)entry).name == nil)
        {
            // Never ever delete .sav files. In case a user's Dropbox account is deleted, even if they lose their save states and cheats they'll still have their .sav file
            if ([entry.pathLower.pathExtension isEqualToString:@"sav"] || [entry.pathLower.pathExtension isEqualToString:@"rtcsav"] || !deleteDeletedDropboxFiles)
            {
                continue;
            }
            
            NSDictionary *cachedDropboxFiles = [[[GBASyncManager sharedManager] dropboxFiles] copy];
            
            for (NSString *key in cachedDropboxFiles)
            {
                if ([[key lowercaseString] isEqualToString:entry.pathLower])
                {
                    [[[GBASyncManager sharedManager] dropboxFiles] removeObjectForKey:key];
                    
                    NSString *localPath = [GBASyncManager localPathForDropboxPath:key uploading:NO];
                    
                    BOOL isDirectory = NO;
                    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory] && !isDirectory)
                    {
                        [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
                    }
                    
                }
            }
            
            [NSKeyedArchiver archiveRootObject:[[GBASyncManager sharedManager] dropboxFiles] toFile:[GBASyncManager dropboxFilesPath]];
            
            continue;
        }
        
        if ([entry.pathLower.pathExtension isEqualToString:@"sav"] || [entry.pathLower.pathExtension isEqualToString:@"rtcsav"] || [entry.pathLower.pathExtension isEqualToString:@"plist"] || [entry.pathLower.pathExtension isEqualToString:@"gbacheat"] || [entry.pathLower.pathExtension isEqualToString:@"sgm"])
        {
            [dropboxFiles setObject:entry forKey:entry.pathLower];
        }
        
    }
    
    return dropboxFiles;
}


@end
