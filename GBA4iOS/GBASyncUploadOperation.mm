//
//  GBASyncUploadOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncUploadOperation.h"
#import "GBASyncOperation_Private.h"
#import "GBASyncFileOperation_Private.h"
#import "GBAROM_Private.h"
#import "GBASyncManager_Private.h"
#import "GBASyncUploadDeviceUploadHistoryOperation.h"

@implementation GBASyncUploadOperation

#pragma mark - Initialization

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath metadata:(DBMetadata *)metadata
{
    self = [super initWithDropboxPath:dropboxPath metadata:metadata];
    
    if (self == nil)
    {
        return nil;
    }
    
    return self;
}

#pragma mark - Upload File

- (void)beginSyncOperation
{
    DBMetadata *metadata = self.metadata;
    NSString *localPath = [GBASyncManager localPathForDropboxPath:self.dropboxPath uploading:YES];
    
    if (metadata == nil)
    {
        NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        metadata = dropboxFiles[self.dropboxPath];
    }
    
    if (metadata.rev)
    {
        DLog(@"Uploading %@... (Replacing Rev %@)", [localPath lastPathComponent], metadata.rev);
    }
    else
    {
        DLog(@"Uploading %@...", [localPath lastPathComponent]);
    }
    
    NSString *localizedString = NSLocalizedString(@"Uploading", @"");
    
    NSString *message = [NSString stringWithFormat:@"%@ %@", localizedString, [self humanReadableFileDescriptionForDropboxPath:self.dropboxPath]];
    
    [self showToastViewWithMessage:message forDuration:0 showActivityIndicator:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.restClient uploadFile:[self.dropboxPath lastPathComponent] toPath:[self.dropboxPath stringByDeletingLastPathComponent] withParentRev:metadata.rev fromPath:localPath];
    });
}


- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)dropboxPath from:(NSString *)localPath metadata:(DBMetadata *)metadata
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Uploaded File: %@ To Path: %@ Rev: %@", [localPath lastPathComponent], metadata.path, metadata.rev);
                
        // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
        NSDictionary *attributes = @{NSFileModificationDate: metadata.lastModifiedDate};
        
        if ([[[dropboxPath pathExtension] lowercaseString] isEqualToString:@"rtcsav"])
        {
            GBAROM *rom = [GBAROM romWithName:[[localPath lastPathComponent] stringByDeletingPathExtension]];
            
            // Delete temporary .rtcsav file if we made one
            BOOL isDirectory = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory] && !isDirectory)
            {
                [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
            }
                           
            [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:rom.saveFileFilepath error:nil];
            [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:rom.rtcFileFilepath error:nil];
            
            NSDate *date = [[[NSFileManager defaultManager] attributesOfItemAtPath:rom.saveFileFilepath error:nil] fileModificationDate];
            
            DLog(@"Dropbox: %@ Local: %@", metadata.lastModifiedDate, date);
        }
        else
        {
            [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:localPath error:nil];
        }
        
        // Pending Uploads
        NSMutableDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
        
        NSString *relativePath = [GBASyncManager relativePathForLocalPath:localPath];
        [[GBASyncManager sharedManager] removeCachedUploadOperationForRelativePath:relativePath];
        [NSKeyedArchiver archiveRootObject:pendingUploads toFile:[GBASyncManager pendingUploadsPath]];
        
        // Dropbox Files
        NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        [dropboxFiles setObject:metadata forKey:metadata.path];
        [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
                
        
        // Only update upload histrory for save files - we only ever use it for this, and keeps the file small
        if ([[[dropboxPath pathExtension] lowercaseString] isEqualToString:@"sav"] || [[[dropboxPath pathExtension] lowercaseString] isEqualToString:@"rtcsav"])
        {
            // Upload History
            NSMutableDictionary *uploadHistory = [[GBASyncManager sharedManager] deviceUploadHistory];
            NSString *uniqueName = [GBASyncManager uniqueROMNameFromDropboxPath:dropboxPath];
            
            NSMutableDictionary *romDictionary = [uploadHistory[uniqueName] mutableCopy];
            
            if (romDictionary == nil)
            {
                romDictionary = [NSMutableDictionary dictionary];
            }
            
            romDictionary[metadata.path] = metadata.rev;
            uploadHistory[uniqueName] = romDictionary;
            
            [uploadHistory writeToFile:[GBASyncManager currentDeviceUploadHistoryPath] atomically:YES];
        }
        
        // Actual location doesn't match intended location
        if (![dropboxPath.lowercaseString isEqualToString:[metadata.path lowercaseString]])
        {
            DLog(@"Conflicted upload for file: %@ Destination Path: %@ Actual Path: %@", metadata.filename, dropboxPath, metadata.path);
            NSString *romName = [[localPath lastPathComponent] stringByDeletingPathExtension];
            GBAROM *rom = [GBAROM romWithName:romName];
            [rom setConflicted:YES];
            [rom setSyncingDisabled:YES];
        }
        
        if (self.updatesDeviceUploadHistoryUponCompletion)
        {
            GBASyncUploadDeviceUploadHistoryOperation *uploadDeviceUploadHistoryOperation = [[GBASyncUploadDeviceUploadHistoryOperation alloc] init];
            //uploadDeviceUploadHistoryOperation.delegate = self.delegate;
            //uploadDeviceUploadHistoryOperation.toastView = self.toastView;
            [uploadDeviceUploadHistoryOperation start];
            [uploadDeviceUploadHistoryOperation waitUntilFinished];
            
            // Don't return stupid
            // return;
        }
        
        [self finishedWithMetadata:metadata error:nil];
    });
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        NSString *localPath = [error userInfo][@"sourcePath"];
        NSString *dropboxPath = [error userInfo][@"destinationPath"];
        
        NSMutableDictionary *pendingUploads = [[GBASyncManager sharedManager] pendingUploads];
        
        if ([error code] == DBErrorFileNotFound) // Not really an error, so we ignore it
        {
            DLog(@"File doesn't exist for upload...ignoring %@", [localPath lastPathComponent]);
            
            NSString *relativePath = [GBASyncManager relativePathForLocalPath:localPath];
            [[GBASyncManager sharedManager] removeCachedUploadOperationForRelativePath:relativePath];
            [NSKeyedArchiver archiveRootObject:pendingUploads toFile:[GBASyncManager pendingUploadsPath]];
            
            [self finishedWithMetadata:self.metadata error:nil];
            
            return;
        }
        
        if ([error code] == 400)
        {
            NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
            [dropboxFiles removeObjectForKey:dropboxPath];
            [NSKeyedArchiver archiveRootObject:dropboxPath toFile:[GBASyncManager dropboxFilesPath]];
        }
        
        DLog(@"Failed to upload file: %@ Error: %@", [localPath lastPathComponent], error);

        [self finishedWithMetadata:self.metadata error:error];
    });
}


@end
