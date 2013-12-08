//
//  GBASyncRenameOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/7/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncRenameOperation.h"
#import "GBASyncOperation_Private.h"
#import "GBASyncUploadDeviceUploadHistoryOperation.h"

#import <DropboxSDK/DropboxSDK.h>

@implementation GBASyncRenameOperation

#pragma mark - Initialization

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath destinationPath:(NSString *)destinationPath
{
    self = [super init];
    
    if (self == nil)
    {
        return nil;
    }
    
    self.dropboxPath = dropboxPath;
    self.destinationPath = destinationPath;
    
    return self;
}

#pragma mark - Rename File

- (void)beginSyncOperation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.restClient moveFrom:self.dropboxPath toPath:self.destinationPath];
    });
}

- (void)restClient:(DBRestClient*)client movedPath:(NSString *)dropboxPath to:(DBMetadata *)metadata
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Moved File: %@ To Path: %@", dropboxPath, metadata.path);
        
        // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
        // NSDictionary *attributes = @{NSFileModificationDate: metadata.lastModifiedDate};
        // [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:self error:nil];
        
        // Pending Renamings
        NSMutableDictionary *pendingRenamings = [[GBASyncManager sharedManager] pendingRenamings];
        [pendingRenamings removeObjectForKey:dropboxPath];
        [pendingRenamings writeToFile:[GBASyncManager pendingRenamingsPath] atomically:YES];
        
        // Dropbox Files
        NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        [dropboxFiles removeObjectForKey:dropboxPath];
        [dropboxFiles setObject:metadata forKey:metadata.path];
        [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
        
        // Upload History
        NSMutableDictionary *uploadHistory = [[GBASyncManager sharedManager] deviceUploadHistory];
        NSString *uniqueName = [GBASyncManager uniqueROMNameFromDropboxPath:dropboxPath];
        
        NSMutableDictionary *romDictionary = [uploadHistory[uniqueName] mutableCopy];
        
        if (romDictionary == nil)
        {
            romDictionary = [NSMutableDictionary dictionary];
        }
        
        [romDictionary removeObjectForKey:dropboxPath];
        [romDictionary setObject:metadata.rev forKey:metadata.path];
        uploadHistory[uniqueName] = romDictionary;
        
        [uploadHistory writeToFile:[GBASyncManager currentDeviceUploadHistoryPath] atomically:YES];
        
        if (self.updatesDeviceUploadHistoryUponCompletion)
        {
            GBASyncUploadDeviceUploadHistoryOperation *uploadDeviceUploadHistoryOperation = [[GBASyncUploadDeviceUploadHistoryOperation alloc] init];
            [uploadDeviceUploadHistoryOperation start];
            [uploadDeviceUploadHistoryOperation waitUntilFinished];
        }
        
        [self finishWithMetadata:metadata error:nil];
        
    });
}

- (void)restClient:(DBRestClient*)client movePathFailedWithError:(NSError *)error
{
    DLog(@"ERROR: %@", [error userInfo]);
    
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        
    });
}

/*- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        NSString *localPath = [error userInfo][@"sourcePath"];
        
        NSMutableDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
        
        if ([error code] == DBErrorFileNotFound) // Not really an error, so we ignore it
        {
            DLog(@"File doesn't exist for upload...ignoring %@", [localPath lastPathComponent]);
            
            [pendingUploads removeObjectForKey:localPath];
            [NSKeyedArchiver archiveRootObject:pendingUploads toFile:[GBASyncManager pendingUploadsPath]];
            
            [self finishedWithMetadata:self.metadata error:nil];
            
            return;
        }
        
        DLog(@"Failed to upload file: %@ Error: %@", [localPath lastPathComponent], [error userInfo]);
        
        [self finishedWithMetadata:self.metadata error:error];
    });
}*/

- (void)finishWithMetadata:(DBMetadata *)metadata error:(NSError *)error
{
    if (self.syncCompletionBlock)
    {
        self.syncCompletionBlock(self.dropboxPath, metadata, error);
    }
    
    [self finish];
}


#pragma mark - Public

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (self.dropboxPath)
    {
        dictionary[GBASyncDropboxPathKey] = self.dropboxPath;
    }
    
    if (self.destinationPath)
    {
        dictionary[GBASyncDestinationPathKey] = self.destinationPath;
    }
    
    return dictionary;
}

@end
