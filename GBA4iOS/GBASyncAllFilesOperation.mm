//
//  GBASyncAllFilesOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncAllFilesOperation.h"
#import "GBASyncMultipleFilesOperation_Private.h"
#import "GBASyncManager_Private.h"

@interface GBASyncAllFilesOperation ()

@property (copy, nonatomic) NSArray *downloadOperations;

@end

@implementation GBASyncAllFilesOperation

#pragma mark - Perform Operation

- (void)beginSyncOperation
{
    [super beginSyncOperation];
    
    DLog(@"Starting Sync...");
    [self requestDeltaEntries];
}

#pragma mark - Get Delta Entries

- (void)requestDeltaEntries
{
    NSDictionary *lastSyncInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncInfo"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        DLog(@"%@", lastSyncInfo[@"cursor"]);
        [[self.restClient.filesRoutes listFolder:/*lastSyncInfo[@"cursor"]*/@""] setResponseBlock:^(DBFILESListFolderResult * _Nullable result, DBFILESListFolderError * _Nullable routeError, DBRequestError * _Nullable networkError) {
            DLog(@"route: %@, network: %@", routeError, networkError);
            if (networkError)
            {
                [self restClient:self.restClient loadDeltaFailedWithError:networkError.nsError];
            }
            else if (result)
            {
                [self restClient:self.restClient loadedDeltaEntries:result.entries cursor:result.cursor hasMore:[result.hasMore boolValue]];
            }
        }];
    });
}

- (void)restClient:(DBUserClient *)client loadedDeltaEntries:(NSArray *)entries cursor:(NSString *)cursor hasMore:(BOOL)hasMore
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Received Delta Entries");
        
        NSDictionary *newDropboxFiles = [self validDropboxFilesFromDeltaEntries:entries deleteDeletedDropboxFiles:YES];
        
        [newDropboxFiles enumerateKeysAndObjectsUsingBlock:^(NSString *key, DBFILESMetadata *metadata, BOOL *stop) {
            [self prepareToDownloadFileWithMetadataIfNeeded:metadata isDeltaChange:YES];
        }];
        
        // Keep cached dropbox files and new dropbox files separate for now, since we use both separately to when actually downloading a file to determine whether a file is conflicted or not
        NSDictionary *cachedDropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        [cachedDropboxFiles enumerateKeysAndObjectsUsingBlock:^(NSString *key, DBFILESMetadata *metadata, BOOL *stop) {
            [self prepareToDownloadFileWithMetadataIfNeeded:metadata isDeltaChange:NO];
        }];
        
        [self prepareToUploadFilesMissingFromDropboxFilesAndConflictIfNeeded:NO];
        
        [self moveFiles];
        
        NSDictionary *dictionary = @{@"date": [NSDate date], @"cursor": [NSString stringWithFormat:@"/%@", cursor]};
        [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:@"lastSyncInfo"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (void)restClient:(DBUserClient*)client loadDeltaFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Delta Failed :(");
        
        // Create a new toast view so it animates on top of the old one
        rst_dispatch_sync_on_main_thread(^{
            self.toastView = [RSTToastView toastViewWithMessage:nil];
            [self showToastViewWithMessage:NSLocalizedString(@"Failed to sync with Dropbox", @"") forDuration:2.0 showActivityIndicator:NO];
        });
        
        
        // Don't call finish sync, as it displays a different message
        [self finish];
    });
}

#pragma mark - Finishing

- (void)finishSync
{
    DLog(@"Finished sync!");
    
    // Create a new toast view so it animates on top of the old one
    rst_dispatch_sync_on_main_thread(^{
        self.toastView = [RSTToastView toastViewWithMessage:nil];
        [self showToastViewWithMessage:NSLocalizedString(@"Sync Complete!", @"") forDuration:1.0 showActivityIndicator:NO];
    });
    
    [super finishSync];
}


@end
