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

#import "SSZipArchive.h"

@implementation GBASyncDownloadOperation

#pragma mark - Initialization

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath metadata:(DBFILESMetadata *)metadata
{
    self = [super initWithDropboxPath:dropboxPath metadata:metadata];
    
    if (self == nil)
    {
        return nil;
    }
    
    return self;
}

#pragma mark - Download File

- (void)beginSyncOperation
{
    NSString *localPath = [GBASyncManager localPathForDropboxPath:self.dropboxPath uploading:NO];
    NSURL *localPathURL = [[NSURL alloc] initWithString:localPath];
    
    DLog(@"Downloading file %@ to %@...", self.dropboxPath, localPath);
    
    NSString *localizedString = NSLocalizedString(@"Downloading", @"");
    NSString *message = [NSString stringWithFormat:@"%@ %@", localizedString, [self humanReadableFileDescriptionForDropboxPath:self.dropboxPath]];
    
    [self showToastViewWithMessage:message forDuration:0 showActivityIndicator:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.metadata)
        {
            DBFILESFileMetadata *fileMetadata = (DBFILESFileMetadata *)self.metadata;
            [[self.restClient.filesRoutes downloadUrl:self.metadata.pathLower rev:fileMetadata.rev overwrite:YES destination:localPathURL] setResponseBlock:^(DBFILESFileMetadata * _Nullable result, DBFILESDownloadError * _Nullable routeError, DBRequestError * _Nullable networkError, NSURL * _Nonnull destination) {
                [self loadedFile:result routeError:routeError networkError:networkError destination:destination];
            }];
        }
        else
        {
            [[self.restClient.filesRoutes downloadUrl:self.dropboxPath overwrite:YES destination:localPathURL] setResponseBlock:^(DBFILESFileMetadata * _Nullable result, DBFILESDownloadError * _Nullable routeError, DBRequestError * _Nullable networkError, NSURL * _Nonnull destination) {
                [self loadedFile:result routeError:routeError networkError:networkError destination:destination];
            }];
        }
    });    
}

- (void)loadedFile:(DBFILESFileMetadata * _Nullable)result routeError:(DBFILESDownloadError * _Nullable)routeError networkError:(DBRequestError * _Nullable)networkError destination:(NSURL * _Nonnull)destination
{
    if (networkError)
    {
        [self restClient:self.restClient loadFileFailedWithError:networkError.nsError];
    }
    else if (result && destination)
    {
        [self restClient:self.restClient loadedFile:destination.absoluteString metadata:result];
    }
}

- (void)restClient:(DBUserClient *)client loadedFile:(NSString *)localPath metadata:(DBFILESMetadata *)metadata
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        DLog(@"Loaded File: %@", localPath);
        NSString *dropboxPath = metadata.pathLower;
        
        // Keep local and dropbox timestamps in sync (so if user messes with the date, everything still works)
        DBFILESFileMetadata *fileMetadata = (DBFILESFileMetadata *)self.metadata;
        NSDictionary *attributes = @{NSFileModificationDate: fileMetadata.serverModified};
        
        if ([localPath.pathExtension.lowercaseString isEqualToString:@"rtcsav"])
        {
            NSString *unzipDirectory = [[localPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[localPath lastPathComponent] stringByDeletingPathExtension]];
            [[NSFileManager defaultManager] removeItemAtPath:unzipDirectory error:nil];
            
            NSError *error = nil;
            if (![SSZipArchive unzipFileAtPath:localPath toDestination:unzipDirectory overwrite:YES password:nil error:&error])
            {
                return [self restClient:client loadFileFailedWithError:error];
            }
            
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:unzipDirectory error:nil];
            
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            
            for (NSString *filename in contents)
            {
                NSString *filepath = [unzipDirectory stringByAppendingPathComponent:filename];
                NSString *destinationPath = [documentsDirectory stringByAppendingPathComponent:filename];
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath])
                {
                    if (![[NSFileManager defaultManager] replaceItemAtURL:[NSURL fileURLWithPath:destinationPath] withItemAtURL:[NSURL fileURLWithPath:filepath] backupItemName:nil options:0 resultingItemURL:nil error:&error])
                    {
                        return [self restClient:client loadFileFailedWithError:error];
                    }
                }
                else
                {
                    if (![[NSFileManager defaultManager] moveItemAtPath:filepath toPath:destinationPath error:&error])
                    {
                        return [self restClient:client loadFileFailedWithError:error];
                    }
                }
                
                [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:destinationPath error:&error];
                
                if ([filepath.pathExtension isEqualToString:@"sav"])
                {
                    NSDate *date = [[[NSFileManager defaultManager] attributesOfItemAtPath:destinationPath error:nil] fileModificationDate];
                    
                    DBFILESFileMetadata *fileMetadata = (DBFILESFileMetadata *)metadata;
                    DLog(@"Dropbox: %@ Local: %@", fileMetadata.serverModified, date);
                    
                }
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:unzipDirectory error:nil];
        }
        else
        {
            [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:localPath error:nil];
        }
                
        // Pending Downloads
        NSMutableDictionary *pendingDownloads = [[GBASyncManager sharedManager] pendingDownloads];
        [pendingDownloads removeObjectForKey:dropboxPath];
        [NSKeyedArchiver archiveRootObject:pendingDownloads toFile:[GBASyncManager pendingDownloadsPath]];
        
        // Dropbox Files
        NSMutableDictionary *dropboxFiles = [[GBASyncManager sharedManager] dropboxFiles];
        [dropboxFiles setObject:metadata forKey:metadata.pathLower];
        [NSKeyedArchiver archiveRootObject:dropboxFiles toFile:[GBASyncManager dropboxFilesPath]];
        
        [self finishedWithMetadata:metadata error:nil];
    });
}

- (void)restClient:(DBUserClient *)client loadFileFailedWithError:(NSError *)error
{
    dispatch_async(self.ugh_dropbox_requiring_main_thread_dispatch_queue, ^{
        
        NSString *dropboxPath = [error userInfo][@"path"];
        
        NSDictionary *dropboxFiles = [[GBASyncManager sharedManager] pendingDownloads];
        DBFILESMetadata *metadata = dropboxFiles[self.dropboxPath];
                
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
