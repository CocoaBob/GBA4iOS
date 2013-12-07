//
//  GBASyncManager_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/26/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GBASyncManager.h"
#import "GBASyncUploadOperation.h"
#import "GBASyncDownloadOperation.h"

extern NSString * const GBASyncLocalPathKey;
extern NSString * const GBASyncDropboxPathKey;
extern NSString * const GBASyncMetadataKey;

@interface GBASyncManager ()

@property (strong, atomic) NSMutableDictionary *dropboxFiles; // Uses remote filepath as keys
@property (strong, atomic) NSSet *conflictedROMs;
@property (strong, atomic) NSSet *syncingDisabledROMs;
@property (strong, atomic) NSMutableDictionary *deviceUploadHistory;

@property (strong, atomic) NSMutableDictionary *pendingUploads; // Uses local filepath as keys
@property (strong, atomic) NSMutableDictionary *pendingDownloads; // Uses remote filepath as keys
@property (strong, atomic) NSMutableDictionary *currentUploads; // Uses local filepaths
@property (strong, atomic) NSMutableDictionary *currentDownloads; // Uses remote filepaths

- (void)cacheUploadOperation:(GBASyncUploadOperation *)uploadOperation;
- (void)cacheDownloadOperation:(GBASyncDownloadOperation *)downloadOperation;

// Filepaths
+ (NSString *)dropboxSyncDirectoryPath;
+ (NSString *)dropboxFilesPath;
+ (NSString *)pendingUploadsPath;
+ (NSString *)pendingDownloadsPath;
+ (NSString *)conflictedROMsPath;
+ (NSString *)syncingDisabledROMsPath;
+ (NSString *)currentDeviceUploadHistoryPath;

+ (NSString *)romNameFromDropboxPath:(NSString *)dropboxPath;
+ (NSString *)uniqueROMNameFromDropboxPath:(NSString *)dropboxPath;

@end
