//
//  GBASyncManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>

#import "GBAROM.h"
#import "GBACheat.h"

extern NSString *const GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification;
extern NSString *const GBAUpdatedDeviceUploadHistoryNotification;

extern NSString *const GBASyncManagerFinishedSyncNotification;

typedef void (^GBASyncCompletionBlock)(NSString *localPath, DBMetadata *metadata, NSError *error);
typedef void (^GBASyncMoveCompletionBlock)(NSString *originalDropboxPath, DBMetadata *destinationMetadata, NSError *error);
typedef void (^GBASyncDeleteCompletionBlock)(NSString *dropboxPath, NSError *error);

@interface GBASyncManager : NSObject

@property (readonly, assign, nonatomic, getter = isSyncing) BOOL syncing;
@property (readonly, assign, nonatomic) BOOL performedInitialSync;
@property (assign, nonatomic) BOOL shouldShowSyncingStatus;

+ (instancetype)sharedManager;

- (void)start;
- (void)synchronize;

- (void)deleteSyncingDataForROMWithName:(NSString *)name uniqueName:(NSString *)uniqueName;

- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom;

- (void)prepareToUploadCheat:(GBACheat *)cheat forROM:(GBAROM *)rom;
- (void)prepareToDeleteCheat:(GBACheat *)cheat forROM:(GBAROM *)rom;

- (void)prepareToUploadSaveStateAtPath:(NSString *)filepath forROM:(GBAROM *)rom;
- (void)prepareToDeleteSaveStateAtPath:(NSString *)filepath forROM:(GBAROM *)rom;
- (void)prepareToRenameSaveStateAtPath:(NSString *)filepath toNewName:(NSString *)filename forROM:(GBAROM *)rom;

- (void)uploadFileAtPath:(NSString *)localPath toDropboxPath:(NSString *)dropboxPath completionBlock:(GBASyncCompletionBlock)completionBlock;
- (void)uploadFileAtPath:(NSString *)localPath withMetadata:(DBMetadata *)metadata completionBlock:(GBASyncCompletionBlock)completionBlock;
- (void)downloadFileToPath:(NSString *)localPath fromDropboxPath:(NSString *)dropboxPath completionBlock:(GBASyncCompletionBlock)completionBlock;
- (void)downloadFileToPath:(NSString *)localPath withMetadata:(DBMetadata *)metadata completionBlock:(GBASyncCompletionBlock)completionBlock;

- (void)moveFileAtDropboxPath:(NSString *)dropboxPath toDestinationPath:(NSString *)destinationPath completionBlock:(GBASyncMoveCompletionBlock)completionBlock;
- (void)deleteFileAtDropboxPath:(NSString *)dropboxPath completionBlock:(GBASyncDeleteCompletionBlock)completionBlock;

- (BOOL)hasPendingDownloadForROM:(GBAROM *)rom;



@end
