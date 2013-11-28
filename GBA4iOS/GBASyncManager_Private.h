//
//  GBASyncManager_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/26/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GBASyncManager.h"

typedef void (^GBASyncingCompletionBlock)(NSString *localPath, NSString *dropboxPath, NSError *error);

typedef NS_ENUM(NSInteger, GBADropboxFileType)
{
    GBADropboxFileTypeUnknown             = 0,
    GBADropboxFileTypeSave                = 1,
    GBADropboxFileTypeSaveState           = 2,
    GBADropboxFileTypeCheat               = 3,
    GBADropboxFileTypeUploadHistory       = 4,
};

@interface GBASyncManager ()

- (void)uploadFileAtPath:(NSString *)path withMetadata:(DBMetadata *)metadata fileType:(GBADropboxFileType)fileType completionBlock:(GBASyncingCompletionBlock)completionBlock;
- (void)downloadFileWithMetadata:(DBMetadata *)metadata toPath:(NSString *)path fileType:(GBADropboxFileType)fileType completionBlock:(GBASyncingCompletionBlock)completionBlock;

@end
