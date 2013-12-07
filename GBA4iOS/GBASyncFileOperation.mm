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

- (instancetype)initWithLocalPath:(NSString *)localPath dropboxPath:(NSString *)dropboxPath
{
    self = [self initWithLocalPath:localPath dropboxPath:dropboxPath metadata:nil];
    
    return self;
}

- (instancetype)initWithLocalPath:(NSString *)localPath metadata:(DBMetadata *)metadata
{
    self = [self initWithLocalPath:localPath dropboxPath:metadata.path metadata:metadata];
    
    return self;
}

- (instancetype)initWithLocalPath:(NSString *)localPath dropboxPath:(NSString *)dropboxPath metadata:(DBMetadata *)metadata
{
    self = [super init];
    
    if (self == nil)
    {
        return nil;
    }
    
    _localPath = [localPath copy];
    _dropboxPath = [dropboxPath copy];
    _metadata = metadata;
    
    return self;
}

#pragma mark - Public

- (void)finishedWithMetadata:(DBMetadata *)metadata error:(NSError *)error
{
    if (self.syncCompletionBlock)
    {
        self.syncCompletionBlock(self.localPath, self.metadata, error);
    }
    
    [self finish];
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (self.localPath)
    {
        dictionary[GBASyncLocalPathKey] = self.localPath;
    }
    
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

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.localPath forKey:@"localPath"];
    [aCoder encodeObject:self.dropboxPath forKey:@"dropboxPath"];
    [aCoder encodeObject:self.metadata forKey:@"metadata"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *localPath = [aDecoder decodeObjectForKey:@"localPath"];
    NSString *dropboxPath = [aDecoder decodeObjectForKey:@"dropboxPath"];
    DBMetadata *metadata = [aDecoder decodeObjectForKey:@"metadata"];
        
    if (metadata)
    {
        self = [self initWithLocalPath:localPath metadata:metadata];
    }
    else
    {
        self = [self initWithLocalPath:localPath dropboxPath:dropboxPath];
    }
        
    return self;
}

@end
