//
//  GBASyncInitialSyncOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncInitialSyncOperation.h"
#import "GBASyncMultipleFilesOperation_Private.h"
#import "GBASyncManager_Private.h"

@implementation GBASyncInitialSyncOperation

#pragma mark - Perform Operation

- (void)beginSyncOperation
{
    [self showToastViewWithMessage:NSLocalizedString(@"Syncing…", @"") forDuration:0 showActivityIndicator:YES];
    [self requestDeltaEntries];
}

#pragma mark - Get Delta Entries

- (void)requestDeltaEntries
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.restClient loadDelta:nil];
    });
}

- (void)restClient:(DBRestClient *)client loadedDeltaEntries:(NSArray *)entries reset:(BOOL)shouldReset cursor:(NSString *)cursor hasMore:(BOOL)hasMore
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Received Delta Entries");
        
        NSDictionary *dropboxFiles = [self dropboxFilesFromDeltaEntries:entries];
        
        [dropboxFiles enumerateKeysAndObjectsUsingBlock:^(NSString *key, DBMetadata *metadata, BOOL *stop) {
            [self prepareToDownloadFileWithMetadataIfNeeded:metadata];
        }];
        
        [self prepareToUploadFilesMissingFromDropboxFiles:dropboxFiles];
        
        [self downloadFiles];
        
        NSDictionary *dictionary = @{@"date": [NSDate date], @"cursor": cursor};
        [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:@"lastSyncInfo"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (void)restClient:(DBRestClient*)client loadDeltaFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Delta Failed :(");
        
        // Create a new toast view so it animates on top of the old one
        self.toastView = [RSTToastView toastViewWithMessage:nil];
        [self showToastViewWithMessage:NSLocalizedString(@"Failed to sync with Dropbox", @"") forDuration:2.0 showActivityIndicator:NO];
        
        // Don't call finish sync, as it displays a different message
        [self finish];
    });
}

#pragma mark - Uploading

- (void)prepareToUploadFilesMissingFromDropboxFiles:(NSDictionary *)dropboxFiles
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
    NSDictionary *cachedDropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
    
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
        NSString *dropboxPath = [NSString stringWithFormat:@"/%@/Saves/%@", uniqueName, [uniqueName stringByAppendingPathExtension:@"sav"]];
        
        // Already marked for upload, don't need to upload again
        if (pendingUploads[filepath])
        {
            continue;
        }
        
        DBMetadata *dropboxMetadata = dropboxFiles[dropboxPath];
        DBMetadata *cachedMetadata = cachedDropboxFiles[dropboxPath];
        
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:rom.saveFileFilepath error:nil];
        NSDate *currentDate = [attributes fileModificationDate];
        NSDate *previousDate = cachedMetadata.lastModifiedDate;

        // If there is dropboxMetadata, and we haven't synced with the latest version, it's conflicted
        if (![dropboxMetadata.rev isEqualToString:cachedMetadata.rev] && dropboxMetadata != nil)
        {
            DLog(@"Conflicted ROM: %@ Local Rev: %@ Dropbox Rev: %@", romName, cachedMetadata.rev, dropboxMetadata.rev);
            
            [rom setConflicted:YES];
            [rom setSyncingDisabled:YES];
            
            continue;
        }
        
        // Cache it to pendingUploads
        GBASyncUploadOperation *uploadOperation = [[GBASyncUploadOperation alloc] initWithLocalPath:rom.saveFileFilepath dropboxPath:dropboxPath];
        [[GBASyncManager sharedManager] cacheUploadOperation:uploadOperation];
    }
    
    [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
    
    // So we don't have to perform this initial sync step again
    [[NSUserDefaults standardUserDefaults] setObject:@{@"date": [NSDate date], @"completed": @NO} forKey:@"initialSync"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Finishing

- (void)finishSync
{
    DLog(@"Finished initial sync!");
    
    // Create a new toast view so it animates on top of the old one
    self.toastView = [RSTToastView toastViewWithMessage:nil];
    [self showToastViewWithMessage:NSLocalizedString(@"Sync Complete!", @"") forDuration:1.0 showActivityIndicator:NO];
    
    [super finishSync];
}

@end
