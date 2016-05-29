//
//  GBASyncFileOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncOperation.h"
#import "GBASyncManager.h"

#import <DropboxSDK/DropboxSDK.h>

@interface GBASyncFileOperation : GBASyncOperation

@property (readonly, copy, nonatomic) NSString *dropboxPath;
@property (readonly, copy, nonatomic) DBMetadata *metadata;

@property (copy, nonatomic) GBASyncCompletionBlock syncCompletionBlock;

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath;
- (instancetype)initWithMetadata:(DBMetadata *)metadata;
- (instancetype)initWithDropboxPath:(NSString *)dropboxPath metadata:(DBMetadata *)metadata; // Operation decides what is most important to use, dropbox or metadata

- (NSDictionary *)dictionaryRepresentation;

@end
