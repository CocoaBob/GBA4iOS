//
//  GBASyncFileOperation_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncFileOperation.h"

@interface GBASyncFileOperation ()

@property (readwrite, copy, nonatomic) NSString *dropboxPath;
@property (readwrite, copy, nonatomic) DBFILESMetadata *metadata;

- (void)finishedWithMetadata:(DBFILESMetadata *)metadata error:(NSError *)error;

- (NSString *)humanReadableFileDescriptionForDropboxPath:(NSString *)dropboxPath;

@end
