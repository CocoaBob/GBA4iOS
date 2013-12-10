//
//  GBASyncRenameOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/7/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncMoveOperation.h"
#import "GBASyncOperation_Private.h"
#import "GBASyncUploadDeviceUploadHistoryOperation.h"

#import <DropboxSDK/DropboxSDK.h>

@implementation GBASyncMoveOperation

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
    DLog(@"Moving File: %@", self.dropboxPath);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.restClient moveFrom:self.dropboxPath toPath:self.destinationPath];
    });
}

- (void)restClient:(DBRestClient*)client movedPath:(NSString *)dropboxPath to:(DBMetadata *)metadata
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Moved File: %@ To Path: %@", [dropboxPath lastPathComponent], [metadata.path lastPathComponent]);
        
        // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
        // NSDictionary *attributes = @{NSFileModificationDate: metadata.lastModifiedDate};
        // [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:self error:nil];
        
        // Pending Renamings
        NSMutableDictionary *pendingMoves = [[GBASyncManager sharedManager] pendingMoves];
        [pendingMoves removeObjectForKey:dropboxPath];
        [pendingMoves writeToFile:[GBASyncManager pendingMovesPath] atomically:YES];
        
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

- (void)restClient:(DBRestClient *)client movePathFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        
        NSString *originalPath = [error userInfo][@"from_path"];
        NSString *destinationPath = [error userInfo][@"to_path"];
        
        NSMutableDictionary *pendingMoves = [[GBASyncManager sharedManager] pendingMoves];
        
        // 403 file already exists
        if ([error code] == DBErrorFileNotFound || [error code] == 403 || [error code] == 404)
        {
            DLog(@"Either file doesn't exist, or another file exists where we are trying to move this one to. Ignoring %@", originalPath);
            
            [pendingMoves removeObjectForKey:originalPath];
            [pendingMoves writeToFile:[GBASyncManager pendingMovesPath] atomically:YES];
            
            [self finishWithMetadata:nil error:nil];
            
            return;
        }
        
        DLog(@"Failed to move file: %@ to file: %@. error: %@", [originalPath lastPathComponent], [destinationPath lastPathComponent], error);
        
        [self finishWithMetadata:nil error:error];
    });
}

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
