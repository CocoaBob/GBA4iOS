//
//  GBASyncManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncManager.h"
#import "GBASettingsViewController.h"

#import <DropboxSDK/DropboxSDK.h>

#define SAVE_FILE_DIRECTORY_NAME @"Saves"

@interface GBASyncManager () <DBRestClientDelegate>
{
    BOOL _performingInitialSync;
    NSMutableSet *_conflictedROMs;
}

@property (strong, nonatomic) DBRestClient *restClient;
@property (strong, nonatomic) NSMutableDictionary *pendingUploads;
@property (strong, nonatomic) NSMutableDictionary *remoteFiles;
@property (readwrite, strong, nonatomic) NSSet *conflictedROMs;

@end

@implementation GBASyncManager
@synthesize conflictedROMs = _conflictedROMs;

#pragma mark - Singleton Methods

+ (instancetype)sharedManager
{
    static GBASyncManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (id)init
{
    if (self = [super init])
    {
        _pendingUploads = [NSMutableDictionary dictionaryWithContentsOfFile:[self pendingUploadsPath]];
        
        if (_pendingUploads == nil)
        {
            _pendingUploads = [NSMutableDictionary dictionary];
        }
        
        _remoteFiles = [NSKeyedUnarchiver unarchiveObjectWithFile:[self remoteFilesPath]];
        
        if (_remoteFiles == nil)
        {
            _remoteFiles = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

- (void)dealloc
{
    // Should never be called, but just here for clarity really.
}

#pragma mark - Syncing

- (void)start
{
    DBSession *session = [[DBSession alloc] initWithAppKey:@"obzx8requbc5bn5" appSecret:@"thdkvkp3hkbmpte" root:kDBRootAppFolder];
    [DBSession setSharedSession:session];
    
    self.restClient = [[DBRestClient alloc] initWithSession:session];
    self.restClient.delegate = self;
    
    if (![[DBSession sharedSession] isLinked])
    {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsDropboxSyncKey];
    }
    else
    {
        [self synchronize];
    }
}

- (void)synchronize
{
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncInfo"] == nil)
    {
        return [self performInitialSync];
    }
    
    [self updateRemoteFiles];
}

#pragma mark - Initial Sync

- (void)performInitialSync
{
    if (_performingInitialSync)
    {
        return;
    }
    
    _performingInitialSync = YES;
    
    [self.restClient loadDelta:nil];
}

- (void)uploadMissingFilesFromRemoteFiles:(NSArray *)remoteFiles
{
    for (DBDeltaEntry *entry in remoteFiles)
    {
        if ([entry.lowercasePath hasSuffix:@"sav"] && ![entry.metadata isDeleted] && entry.metadata.path != nil)
        {
            [self.remoteFiles setObject:entry.metadata forKey:entry.metadata.path];
        }
    }
    
    [NSKeyedArchiver archiveRootObject:self.remoteFiles toFile:[self remoteFilesPath]];
    
    _performingInitialSync = NO;
    
}

#pragma mark - Update Remote Files

- (void)updateRemoteFiles
{
    NSDictionary *pendingUploads = [self.pendingUploads copy];
    
    if ([pendingUploads count] > 0)
    {
        [pendingUploads enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *uploadDictionary, BOOL *stop) {
            DBMetadata *metadata = self.remoteFiles[key];
            
            DLog(@"Replacing %@ Rev %@", uploadDictionary[@"remoteFilename"], metadata.rev);
            
            [self.restClient uploadFile:uploadDictionary[@"remoteFilename"] toPath:uploadDictionary[@"remoteDirectory"] withParentRev:metadata.rev fromPath:uploadDictionary[@"localPath"]];
        }];
    }
    else
    {
        [self updateLocalFiles];
    }
}


- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath metadata:(DBMetadata *)metadata
{
    DLog(@"Uploaded File: %@", srcPath);
    
    [self.pendingUploads removeObjectForKey:srcPath];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
    
    [self.remoteFiles setObject:metadata forKey:srcPath];
    [NSKeyedArchiver archiveRootObject:self.remoteFiles toFile:[self remoteFilesPath]];
    
    
    [[[UIAlertView alloc] initWithTitle:@"Uploaded Files" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    
    if ([self.pendingUploads count] == 0)
    {
        [self updateLocalFiles];
    }
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    DLog(@"Upload Failed :( %@", error);
    
    [[[UIAlertView alloc] initWithTitle:@"Upload Failed :(" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

#pragma mark - Update Local Files

- (void)updateLocalFiles
{
    NSDictionary *lastSyncInfo = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastSyncInfo"];
    
    [self.restClient loadDelta:lastSyncInfo[@"cursor"]];
}

- (void)restClient:(DBRestClient *)client loadedDeltaEntries:(NSArray *)entries reset:(BOOL)shouldReset cursor:(NSString *)cursor hasMore:(BOOL)hasMore
{
    NSDictionary *dictionary = @{@"date": [NSDate date], @"cursor": cursor};
    [[NSUserDefaults standardUserDefaults] setObject:dictionary forKey:@"lastSyncInfo"];
    
    if (_performingInitialSync)
    {
        [self uploadMissingFilesFromRemoteFiles:entries];
        return;
    }
    
    for (DBDeltaEntry *entry in entries)
    {
        if ([entry.lowercasePath hasSuffix:@"sav"] && ![entry.metadata isDeleted] && entry.metadata.path != nil)
        {
            DLog(@"%@", entry.metadata.filename);
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
            
            // DO NOT use lowercase path for writing to disk on iPhone - files are case-sensitive
            [self.restClient loadFile:entry.metadata.path intoPath:[documentsDirectory stringByAppendingPathComponent:[entry.metadata.path lastPathComponent]]];
        }
    }
    
    DLog(@"Updated Local Files");
}

- (void)restClient:(DBRestClient*)client loadDeltaFailedWithError:(NSError *)error
{
    DLog(@"Delta Failed :(");
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath contentType:(NSString *)contentType metadata:(DBMetadata *)metadata
{
    [[[UIAlertView alloc] initWithTitle:@"Loaded Files" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    
    DLog(@"Loaded File!: %@", destPath);
    
    [self.remoteFiles setObject:metadata forKey:destPath];
    [NSKeyedArchiver archiveRootObject:self.remoteFiles toFile:[self remoteFilesPath]];
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error
{
    [[[UIAlertView alloc] initWithTitle:@"Failed to Load Files" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

#pragma mark - Mark Files For Update

- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom
{
    NSString *savesDirectory = [NSString stringWithFormat:@"/%@/%@/", rom.name, SAVE_FILE_DIRECTORY_NAME];
    NSString *saveFileFilename = [rom.saveFileFilepath lastPathComponent];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSDictionary *uploadDictionary = @{@"localPath": [documentsDirectory stringByAppendingPathComponent:saveFileFilename], @"remoteDirectory": savesDirectory, @"remoteFilename": saveFileFilename};
    
    [self.pendingUploads setObject:uploadDictionary forKey:[documentsDirectory stringByAppendingPathComponent:saveFileFilename]];
    [self.pendingUploads writeToFile:[self pendingUploadsPath] atomically:YES];
}

#pragma mark - Application State

- (void)didEnterBackground:(NSNotification *)notification
{
    [self synchronize];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    [self synchronize];
}

#pragma mark - Helper Methods

- (NSString *)dropboxSyncDirectoryPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dropboxDirectory = [libraryDirectory stringByAppendingPathComponent:@"Dropbox Sync"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:dropboxDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return dropboxDirectory;
}

- (NSString *)pendingUploadsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"pendingUploads.plist"];
}

- (NSString *)remoteFilesPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"remoteFiles.plist"];
}

- (NSString *)conflictedROMs
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"conflictedROMs.plist"];
}

@end
