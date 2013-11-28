//
//  GBASyncManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>

#import "GBAROM_Private.h"

extern NSString *const GBAFileDeviceName;

extern NSString *const GBAHasUpdatedSaveForCurrentGameFromDropboxNotification;

@interface GBASyncManager : NSObject

@property (readonly, assign, nonatomic, getter = isSyncing) BOOL syncing;

+ (instancetype)sharedManager;

- (void)start;
- (void)performInitialSync;
- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom;

- (BOOL)isDownloadingDataForROM:(GBAROM *)rom;

- (void)synchronize;

@end
