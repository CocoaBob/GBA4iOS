//
//  GBASyncFileOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncOperation.h"
#import "GBASyncManager.h"

#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>

@interface GBASyncFileOperation : GBASyncOperation

@property (readonly, copy, nonatomic) NSString *dropboxPath;
@property (readonly, copy, nonatomic) DBFILESMetadata *metadata;

@property (copy, nonatomic) GBASyncCompletionBlock syncCompletionBlock;

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath;
- (instancetype)initWithMetadata:(DBFILESMetadata *)metadata;
- (instancetype)initWithDropboxPath:(NSString *)dropboxPath metadata:(DBFILESMetadata *)metadata; // Operation decides what is most important to use, dropbox or metadata

- (NSDictionary *)dictionaryRepresentation;

@end
