//
//  GBASyncUploadHistoryOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncUploadDeviceUploadHistoryOperation.h"
#import "GBASyncOperation_Private.h"
#import "GBASyncFileOperation_Private.h"
#import "GBASyncManager_Private.h"

@implementation GBASyncUploadDeviceUploadHistoryOperation

- (instancetype)init
{
    self = [super init];
    
    if (self == nil)
    {
        return nil;
    }
    
    NSString *deviceName = [[UIDevice currentDevice] name];
    
    self.dropboxPath = [[NSString stringWithFormat:@"/Upload History/%@.plist", deviceName] copy];
    
    return self;
}

#pragma mark - Upload File

- (void)beginSyncOperation
{
    [self showToastViewWithMessage:NSLocalizedString(@"Updating Dropbox status…", @"") forDuration:0 showActivityIndicator:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[self.restClient.filesRoutes uploadUrl:self.dropboxPath mode:[[DBFILESWriteMode alloc] initWithOverwrite] autorename:[NSNumber numberWithBool:NO] clientModified:nil mute:[NSNumber numberWithBool:YES] inputUrl:[GBASyncManager localPathForDropboxPath:self.dropboxPath uploading:YES]] setResponseBlock:^(DBFILESFileMetadata * _Nullable result, DBFILESUploadError * _Nullable routeError, DBRequestError * _Nullable networkError) {
            if (networkError)
            {
                [self restClient:self.restClient uploadFileFailedWithError:networkError.nsError];
            }
            else if (result)
            {
                DLog(@"Recieved result: %@", result);
                [self restClient:self.restClient uploadedFile:self.dropboxPath from:[GBASyncManager localPathForDropboxPath:self.dropboxPath uploading:YES] metadata:result];
            }
        }];
#pragma clang diagnostic pop
    });
}

- (void)restClient:(DBUserClient *)client uploadedFile:(NSString *)dropboxPath from:(NSString *)localPath metadata:(DBFILESMetadata *)metadata
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DBFILESFileMetadata *fileMetadata = (DBFILESFileMetadata *)metadata;
        DLog(@"Uploaded File: %@ To Path: %@ Rev: %@", [localPath lastPathComponent], dropboxPath, fileMetadata.rev);
        
        // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
        NSDictionary *attributes = @{NSFileModificationDate: fileMetadata.serverModified};
        [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:localPath error:nil];
        
        // Pending Uploads
        NSMutableDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
        
        NSString *relativePath = [GBASyncManager relativePathForLocalPath:localPath];
        [[GBASyncManager sharedManager] removeCachedUploadOperationForRelativePath:relativePath];
        [NSKeyedArchiver archiveRootObject:pendingUploads toFile:[GBASyncManager pendingUploadsPath]];
        
        // Dropbox Files
        NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        [dropboxFiles setObject:metadata forKey:metadata.pathLower];
        [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
        
        [self finishedWithMetadata:metadata error:nil];
    });
}

- (void)restClient:(DBUserClient *)client uploadFileFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        NSString *localPath = [error userInfo][@"sourcePath"];
        
        NSMutableDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
        
        if (/*[error code] == DBErrorFileNotFound*/NO) // Not really an error, so we ignore it
        {
            DLog(@"File doesn't exist for upload...ignoring %@", [localPath lastPathComponent]);
            
            NSString *relativePath = [GBASyncManager relativePathForLocalPath:localPath];
            [[GBASyncManager sharedManager] removeCachedUploadOperationForRelativePath:relativePath];
            [NSKeyedArchiver archiveRootObject:pendingUploads toFile:[GBASyncManager pendingUploadsPath]];
            
            [self finishedWithMetadata:self.metadata error:nil];
            
            return;
        }
        
        DLog(@"Failed to upload file: %@ Error: %@", [localPath lastPathComponent], [error userInfo]);
        
        [self finishedWithMetadata:self.metadata error:error];
    });
}

@end
