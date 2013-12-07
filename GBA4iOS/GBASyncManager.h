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

typedef void (^GBASyncCompletionBlock)(NSString *localPath, DBMetadata *metadata, NSError *error);

@interface GBASyncManager : NSObject

@property (readonly, assign, nonatomic, getter = isSyncing) BOOL syncing;
@property (readonly, assign, nonatomic) BOOL performedInitialSync;
@property (assign, nonatomic) BOOL shouldShowSyncingStatus;

+ (instancetype)sharedManager;

- (void)start;
- (void)synchronize;

- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom;
- (void)prepareToUploadCheatsForROM:(GBAROM *)rom;

- (void)uploadFileAtPath:(NSString *)localPath toDropboxPath:(NSString *)dropboxPath completionBlock:(GBASyncCompletionBlock)completionBlock;
- (void)uploadFileAtPath:(NSString *)localPath withMetadata:(DBMetadata *)metadata completionBlock:(GBASyncCompletionBlock)completionBlock;
- (void)downloadFileToPath:(NSString *)localPath fromDropboxPath:(NSString *)dropboxPath completionBlock:(GBASyncCompletionBlock)completionBlock;
- (void)downloadFileToPath:(NSString *)localPath withMetadata:(DBMetadata *)metadata completionBlock:(GBASyncCompletionBlock)completionBlock;

- (BOOL)hasPendingDownloadForROM:(GBAROM *)rom;



@end
