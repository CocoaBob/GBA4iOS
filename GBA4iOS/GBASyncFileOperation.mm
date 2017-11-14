//
//  GBASyncFileOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncFileOperation_Private.h"
#import "GBASyncManager_Private.h"

@implementation GBASyncFileOperation

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath
{
    self = [self initWithDropboxPath:dropboxPath metadata:nil];
    
    return self;
}

- (instancetype)initWithMetadata:(DBFILESMetadata *)metadata
{
    self = [self initWithDropboxPath:metadata.pathLower metadata:metadata];
    
    return self;
}

- (instancetype)initWithDropboxPath:(NSString *)dropboxPath metadata:(DBFILESMetadata *)metadata
{
    self = [super init];
    
    if (self == nil)
    {
        return nil;
    }
    
    _dropboxPath = [dropboxPath copy];
    _metadata = metadata;
    
    return self;
}

#pragma mark - Public

- (void)finishedWithMetadata:(DBFILESMetadata *)metadata error:(NSError *)error
{
    if (self.syncCompletionBlock)
    {
        self.syncCompletionBlock([GBASyncManager localPathForDropboxPath:self.dropboxPath uploading:NO], self.metadata, error);
    }
    
    [self finish];
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (self.dropboxPath)
    {
        dictionary[GBASyncDropboxPathKey] = self.dropboxPath;
    }
    
    if (self.metadata)
    {
        dictionary[GBASyncMetadataKey] = self.metadata;
    }
    
    return dictionary;
}

- (NSString *)humanReadableFileDescriptionForDropboxPath:(NSString *)dropboxPath
{
    NSString *romName = [GBASyncManager romNameFromDropboxPath:self.dropboxPath];
    
    if (romName == nil || [romName isEqualToString:@"Upload History"])
    {
        return NSLocalizedString(@"Files", @"");
    }
    
    NSString *fileDescription = NSLocalizedString(@"files", @"");
    
    if ([dropboxPath.pathExtension isEqualToString:@"sav"] || [dropboxPath.pathExtension isEqualToString:@"rtcsav"])
    {
        fileDescription = NSLocalizedString(@"save", @"");
    }
    else if ([dropboxPath.pathExtension isEqualToString:@"gbacheat"])
    {
        fileDescription = NSLocalizedString(@"cheats", @""); // Intentionally plural
    }
    else if ([dropboxPath.pathExtension isEqualToString:@"sgm"])
    {
        fileDescription = NSLocalizedString(@"save states", @""); // Intentionally plural
    }
    
    return [NSString stringWithFormat:@"%@ %@", romName, fileDescription];
}

@end
