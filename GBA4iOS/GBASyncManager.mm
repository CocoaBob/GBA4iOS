//
//  GBASyncManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncManager.h"
#import "GBASettingsViewController.h"

#import <Dropbox/Dropbox.h>

@interface GBASyncManager ()

@property (readwrite, strong, nonatomic) NSMutableSet *conflictedFiles;

@end

@implementation GBASyncManager

#pragma mark - C Methods

void updateRemoteFileWithFileAtPath(const char *path)
{
    NSString *filepath = [NSString stringWithUTF8String:path];
    [[GBASyncManager sharedManager] updateRemoteFileWithFileAtPath:filepath];
}

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
        _conflictedFiles = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc
{
    // Should never be called, but just here for clarity really.
}

#pragma mark - Update Local Files

- (void)start
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        DBAccountManager *accountManager = [[DBAccountManager alloc] initWithAppKey:@"obzx8requbc5bn5" secret:@"thdkvkp3hkbmpte"];
        [DBAccountManager setSharedManager:accountManager];
        
        [self updateFilesystem];
        
        [[DBAccountManager sharedManager] addObserver:self block:^(DBAccount *account) {
            [self updateFilesystem];
        }];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:GBASettingsDidChangeNotification object:nil];
        
        [self updateLocalFiles];
    });
}

- (void)synchronize
{
}

- (void)updateFilesystem
{
    [[DBFilesystem sharedFilesystem] removeObserver:self];
    
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    
    if (account)
    {
        DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:account];
        [DBFilesystem setSharedFilesystem:filesystem];
    }
    else
    {
        [DBFilesystem setSharedFilesystem:nil];
    }
    
    [[DBFilesystem sharedFilesystem] addObserver:self block:^{
        [self filesystemStatusDidChange];
    }];
}

- (void)updateLocalFiles
{
    NSArray *files = [[DBFilesystem sharedFilesystem] listFolder:[self deviceDirectory] error:nil];
    
    for (DBFileInfo *info in files)
    {
        DBFile *file = [[DBFilesystem sharedFilesystem] openFile:info.path error:nil];
        NSData *data = [file readData:nil];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        
        [data writeToFile:[documentsDirectory stringByAppendingPathComponent:[info.path.stringValue lastPathComponent]] atomically:YES];
    }
    
    DLog(@"Finished Syncing");
}

#pragma mark - Status

- (void)filesystemStatusDidChange
{
    DBSyncStatus status = [DBFilesystem sharedFilesystem].status;
    
    NSMutableString *statusString = [NSMutableString string];
    
    if (status & DBSyncStatusSyncing)
    {
        [statusString appendString:@"Syncing "];
    }
    if (status & DBSyncStatusDownloading)
    {
        [statusString appendString:@"Downloading "];
    }
    if (status & DBSyncStatusUploading)
    {
        [statusString appendString:@"Uploading "];
    }
    
    DLog(@"%@", statusString);
}

#pragma mark - Manually Updating Remote Files

- (void)updateRemoteFileWithFileAtPath:(NSString *)path
{
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    
    if (account == nil)
    {
        return;
    }
    
    NSString *filename = [path lastPathComponent];
    DBPath *dropboxPath = [self pathForFilename:filename];
    
    NSError *error = nil;
    DBFile *file = nil;
    
    DBFileInfo *fileInfo = [[DBFilesystem sharedFilesystem] fileInfoForPath:dropboxPath error:&error];
    
    if (fileInfo)
    {
        file = [[DBFilesystem sharedFilesystem] openFile:dropboxPath error:&error];
    }
    else
    {
        file = [[DBFilesystem sharedFilesystem] createFile:dropboxPath error:&error];
    }
    
    BOOL success = [file writeContentsOfFile:path shouldSteal:NO error:&error];
    
    if (!success)
    {
        DLog(@"Didn't work :( %@ %@", error, [error userInfo]);
    }
}

#pragma mark - Helper Methods

- (DBPath *)deviceDirectory
{
    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    NSString *identifier = [uuid UUIDString];
    
    DBPath *path = [[DBPath root] childPath:identifier];
    
    return path;
}

- (DBPath *)pathForFilename:(NSString *)filename
{
    DBPath *deviceDirectory = [self deviceDirectory];
    return [deviceDirectory childPath:filename];
}
                      


#pragma mark - Private

- (void)updateSettings:(NSNotification *)notification
{
    NSString *key = [notification userInfo][@"key"];
    
    if ([key isEqualToString:GBASettingsDropboxSyncKey])
    {
        
    }
}

@end
