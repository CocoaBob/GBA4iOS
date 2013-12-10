//
//  GBASyncRenameOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/7/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncOperation.h"
#import "GBASyncManager_Private.h"

@interface GBASyncMoveOperation : GBASyncOperation

@property (copy, nonatomic) NSString *dropboxPath;
@property (copy, nonatomic) NSString *destinationPath;
@property (copy, nonatomic) GBASyncMoveCompletionBlock syncCompletionBlock;
@property (assign, nonatomic) BOOL updatesDeviceUploadHistoryUponCompletion;

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath destinationPath:(NSString *)destinationPath;

- (NSDictionary *)dictionaryRepresentation;

@end
