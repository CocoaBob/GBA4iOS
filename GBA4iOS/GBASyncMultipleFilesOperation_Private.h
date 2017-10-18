//
//  GBASyncMultipleFilesOperation_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncMultipleFilesOperation.h"
#import "GBASyncOperation_Private.h"
#import "GBAROM_Private.h"
#import "GBASyncDownloadOperation.h"
#import "GBASyncUploadOperation.h"
#import "GBASyncUploadDeviceUploadHistoryOperation.h"

#import "GBAEmulatorCore.h"

extern NSString *const GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification;

@interface GBASyncMultipleFilesOperation ()

@property (strong, nonatomic) NSOperationQueue *uploadOperationQueue;
@property (strong, nonatomic) NSOperationQueue *downloadOperationQueue;
@property (strong, nonatomic) NSOperationQueue *movingOperationQueue;
@property (strong, nonatomic) NSOperationQueue *deletionOperationQueue;

@property (strong, nonatomic) RSTToastView *dropboxStatusToastView;

- (void)uploadFiles;
- (void)downloadFiles;
- (void)moveFiles;
- (void)deleteFiles;

// Overrides
- (void)finishSync;

- (BOOL)romExistsWithName:(NSString *)name;
- (NSDictionary *)validDropboxFilesFromDeltaEntries:(NSArray *)entries deleteDeletedDropboxFiles:(BOOL)deleteDeletedDropboxFiles;

- (void)prepareToUploadFilesMissingFromDropboxFilesAndConflictIfNeeded:(BOOL)conflictIfNeeded;
- (void)prepareToDownloadFileWithMetadataIfNeeded:(DBFILESMetadata *)metadata isDeltaChange:(BOOL)deltaChange;

@end
