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
#import "GBASyncDeleteOperation.h"
#import "GBASyncMoveOperation.h"

extern NSString * const GBASyncDropboxPathKey;
extern NSString * const GBASyncMetadataKey;
extern NSString * const GBASyncDestinationPathKey;

@class GBASyncDeleteOperation;
@class GBASyncMoveOperation;

@interface GBASyncManager ()

@property (strong, atomic) NSMutableDictionary *dropboxFiles; // Uses remote filepath as keys
@property (strong, atomic) NSMutableSet *conflictedROMs;
@property (strong, atomic) NSMutableSet *syncingDisabledROMs;
@property (strong, atomic) NSMutableDictionary *deviceUploadHistory;

@property (strong, atomic) NSMutableDictionary *pendingUploads; // Uses local filepath as keys
@property (strong, atomic) NSMutableDictionary *pendingDownloads; // Uses remote filepath as keys
@property (strong, atomic) NSMutableDictionary *pendingDeletions; // Uses remote filepath as keys
@property (strong, atomic) NSMutableDictionary *pendingMoves; // Uses remote filepath as keys

- (void)cacheUploadOperation:(GBASyncUploadOperation *)uploadOperation;
- (void)cacheDownloadOperation:(GBASyncDownloadOperation *)downloadOperation;
- (void)cacheDeleteOperation:(GBASyncDeleteOperation *)deleteOperation;
- (void)cacheMoveOperation:(GBASyncMoveOperation *)moveOperation;

- (void)removeCachedUploadOperationForRelativePath:(NSString *)relativePath;

// Filepaths
+ (NSString *)dropboxSyncDirectoryPath;
+ (NSString *)dropboxFilesPath;
+ (NSString *)pendingUploadsPath;
+ (NSString *)pendingDownloadsPath;
+ (NSString *)pendingDeletionsPath;
+ (NSString *)pendingMovesPath;
+ (NSString *)conflictedROMsPath;
+ (NSString *)syncingDisabledROMsPath;
+ (NSString *)cachedROMsPath;
+ (NSString *)currentDeviceUploadHistoryPath;
+ (NSString *)cheatsDirectoryForROM:(GBAROM *)rom;
+ (NSString *)saveStateDirectoryForROM:(GBAROM *)rom;

+ (NSString *)localPathForDropboxPath:(NSString *)dropboxPath uploading:(BOOL)uploading;
+ (NSString *)relativePathForLocalPath:(NSString *)localPath;
+ (NSString *)zippedDropboxPathForSaveFileDropboxPath:(NSString *)dropboxPath;
+ (NSString *)zippedLocalPathForUploadingSaveFileForROM:(GBAROM *)rom;
+ (NSString *)zippedLocalPathForDownloadingSaveFileForROM:(GBAROM *)rom;

+ (NSString *)romNameFromDropboxPath:(NSString *)dropboxPath;
+ (NSString *)uniqueROMNameFromDropboxPath:(NSString *)dropboxPath;

- (BOOL)pendingMoveToOrFromDropboxPath:(NSString *)dropboxPath;

@end
