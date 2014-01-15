//
//  GBASyncDownloadOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncDownloadOperation.h"
#import "GBASyncOperation_Private.h"
#import "GBASyncFileOperation_Private.h"
#import "GBASyncManager_Private.h"

@implementation GBASyncDownloadOperation

#pragma mark - Initialization

- (instancetype)initWithLocalPath:(NSString *)localPath dropboxPath:(NSString *)dropboxPath metadata:(DBMetadata *)metadata
{
    self = [super initWithLocalPath:localPath dropboxPath:dropboxPath metadata:metadata];
    
    if (self == nil)
    {
        return nil;
    }
    
    return self;
}

#pragma mark - Download File

- (void)beginSyncOperation
{
    DLog(@"Downloading file %@ to %@...", self.dropboxPath, self.localPath);
    
    NSString *localizedString = NSLocalizedString(@"Downloading", @"");
    NSString *message = [NSString stringWithFormat:@"%@ %@", localizedString, [self humanReadableFileDescriptionForDropboxPath:self.dropboxPath]];
    
    [self showToastViewWithMessage:message forDuration:0 showActivityIndicator:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.metadata)
        {
            [self.restClient loadFile:self.metadata.path atRev:self.metadata.rev intoPath:self.localPath];
        }
        else
        {
            [self.restClient loadFile:self.dropboxPath intoPath:self.localPath];
        }
    });    
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)localPath contentType:(NSString *)contentType metadata:(DBMetadata *)metadata
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Loaded File: %@", localPath);
        NSString *dropboxPath = metadata.path;
        
        // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
        NSDictionary *attributes = @{NSFileModificationDate: metadata.lastModifiedDate};
        [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:localPath error:nil];
        
        // Pending Downloads
        NSMutableDictionary *pendingDownloads = [[GBASyncManager sharedManager] pendingDownloads];
        [pendingDownloads removeObjectForKey:dropboxPath];
        [NSKeyedArchiver archiveRootObject:pendingDownloads toFile:[GBASyncManager pendingDownloadsPath]];
        
        // Dropbox Files
        NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        [dropboxFiles setObject:metadata forKey:metadata.path];
        [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
        
        [self finishedWithMetadata:metadata error:nil];
    });
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        
        NSString *dropboxPath = [error userInfo][@"path"];
        NSString *localPath = self.localPath;
        
        NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] pendingDownloads];
        DBMetadata *metadata = dropboxFiles[self.dropboxPath];
        
        
        
        if ([error code] == 404) // 404: File has been deleted (according to dropbox)
        {
            DLog(@"File doesn't exist for download...ignoring %@", [dropboxPath lastPathComponent]);
            
            NSMutableDictionary *pendingDownloads = [[GBASyncManager sharedManager] pendingDownloads];
            [pendingDownloads removeObjectForKey:dropboxPath];
            [NSKeyedArchiver archiveRootObject:pendingDownloads toFile:[GBASyncManager pendingDownloadsPath]];
            
            NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
            [dropboxFiles removeObjectForKey:dropboxPath];
            [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
            
            [self finishedWithMetadata:metadata error:nil];
            
            return;
        }
        
        DLog(@"Failed to load file: %@ Error: %@", [dropboxPath lastPathComponent], [error userInfo]);
        
        [self finishedWithMetadata:metadata error:error];
    });
    
}

@end
