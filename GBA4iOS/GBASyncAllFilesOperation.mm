//
//  GBASyncAllFilesOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncAllFilesOperation.h"
#import "GBASyncMultipleFilesOperation_Private.h"

@interface GBASyncAllFilesOperation ()

@property (copy, nonatomic) NSArray *downloadOperations;

@end

@implementation GBASyncAllFilesOperation

#pragma mark - Perform Operation

- (void)beginSyncOperation
{
    DLog(@"Starting Sync...");
    [self showToastViewWithMessage:NSLocalizedString(@"Syncing…", @"") forDuration:0 showActivityIndicator:YES];
    [self requestDeltaEntries];
}

#pragma mark - Get Delta Entries

- (void)requestDeltaEntries
{
    NSDictionary *lastSyncInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncInfo"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.restClient loadDelta:lastSyncInfo[@"cursor"]];
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

#pragma mark - Finishing

- (void)finishSync
{
    DLog(@"Finished sync!");
    
    // Create a new toast view so it animates on top of the old one
    self.toastView = [RSTToastView toastViewWithMessage:nil];
    [self showToastViewWithMessage:NSLocalizedString(@"Sync Complete!", @"") forDuration:1.0 showActivityIndicator:NO];
    
    [super finishSync];
}


@end
