//
//  GBASyncDeleteOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/7/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncDeleteOperation.h"
#import "GBASyncOperation_Private.h"
#import "GBASyncUploadDeviceUploadHistoryOperation.h"

#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>

@implementation GBASyncDeleteOperation

#pragma mark - Initialization

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath
{
    self = [super init];
    
    if (self == nil)
    {
        return nil;
    }
    
    self.dropboxPath = dropboxPath;
    
    return self;
}

#pragma mark - Delete File

- (void)beginSyncOperation
{
    DLog(@"Deleting File: %@", self.dropboxPath);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self.restClient.filesRoutes delete_V2:self.dropboxPath]
         setResponseBlock:^(DBFILESDeleteResult * _Nullable result,
                            DBFILESDeleteError * _Nullable routeError,
                            DBRequestError * _Nullable networkError) {
            if (networkError)
            {
                [self restClient:self.restClient deletePathFailedWithError:networkError.nsError routeError:routeError];
            }
            else if (result)
            {
                [self restClient:self.restClient deletedPath:result.metadata.pathLower];
            }
        }];
    });
}

- (void)restClient:(DBUserClient*)client deletedPath:(NSString *)dropboxPath
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Deleted File: %@", [dropboxPath lastPathComponent]);
        
        // Pending Deletions
        NSMutableDictionary *pendingDeletions = [[GBASyncManager sharedManager] pendingDeletions];
        [pendingDeletions removeObjectForKey:dropboxPath];
        [pendingDeletions writeToFile:[GBASyncManager pendingDeletionsPath] atomically:YES];
        
        // Dropbox Files
        NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        [dropboxFiles removeObjectForKey:dropboxPath];
        [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
        
        // Upload History
        NSString *uniqueName = [GBASyncManager uniqueROMNameFromDropboxPath:dropboxPath];
        NSMutableDictionary *uploadHistory = [[GBASyncManager sharedManager] deviceUploadHistory];
        [uploadHistory removeObjectForKey:dropboxPath];
        [uploadHistory writeToFile:[GBASyncManager currentDeviceUploadHistoryPath] atomically:YES];

        if (self.updatesDeviceUploadHistoryUponCompletion)
        {
            GBASyncUploadDeviceUploadHistoryOperation *uploadDeviceUploadHistoryOperation = [[GBASyncUploadDeviceUploadHistoryOperation alloc] init];
            [uploadDeviceUploadHistoryOperation start];
        }
        
        [self finishSyncWithError:nil];
    });
}

- (void)restClient:(DBUserClient*)client deletePathFailedWithError:(NSError *)error routeError:(DBFILESDeleteError *)routeError
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        NSString *dropboxPath = [error userInfo][@"path"] ?: self.dropboxPath;
        
        if (/*[error code] == DBErrorFileNotFound*/(routeError && [routeError pathLookup].tag == DBFILESLookupErrorNotFound) || [error code] == 404)
        {
            DLog(@"File doesn't exist for deletion, so ignoring %@", [dropboxPath lastPathComponent]);
            
            NSMutableDictionary *pendingDeletions = [[GBASyncManager sharedManager] pendingDeletions];
            if (dropboxPath) [pendingDeletions removeObjectForKey:dropboxPath];
            [pendingDeletions writeToFile:[GBASyncManager pendingDeletionsPath] atomically:YES];
            
            [self finishSyncWithError:nil];
            
            return;
        }
        
        DLog(@"Failed to delete file: %@. Error: %@", dropboxPath, error);
        
        [self finishSyncWithError:error];
    });
}

- (void)finishSyncWithError:(NSError *)error
{
    if (self.syncCompletionBlock)
    {
        self.syncCompletionBlock(self.dropboxPath, error);
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
    
    return dictionary;
}

@end
