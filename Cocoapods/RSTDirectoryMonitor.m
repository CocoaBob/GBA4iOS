//
//  RSTDirectoryMonitor.m
//
//  Created by Riley Testut on 7/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//
//  HEAVILY based on DocWatchHelper, which can be found in The Core iOS 6 Developer's Cookbook by the fantastic Erica Sadun. http://www.amazon.com/Core-Developers-Cookbook-Edition-Library/dp/0321884213
//

#import "RSTDirectoryMonitor.h"

@interface RSTDirectoryMonitor ()

@property (assign, nonatomic) int fileDescriptor;
@property (strong, nonatomic) dispatch_queue_t directory_monitor_queue;
@property (strong, nonatomic) dispatch_source_t directory_monitor_source;
@property (copy, nonatomic) NSArray *previousContents;

@property (strong, nonatomic) NSMutableSet *unavailableFilesSet;

@end

@implementation RSTDirectoryMonitor

- (instancetype)initWithDirectory:(NSString *)directory
{
    self = [super init];
    if (self)
    {
        _unavailableFilesSet = [NSMutableSet set];
        _directory_monitor_queue = dispatch_queue_create("RSTDirectoryMonitor Queue", 0);
        [self setDirectory:directory];
    }
    
    return self;
}

- (void)setDirectory:(NSString *)directory
{
    if ([_directory isEqualToString:directory])
    {
        return;
    }
    
    _directory = [directory copy];
    
    self.previousContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    
    if (self.fileDescriptor)
    {
        close(self.fileDescriptor);
    }
    
    if (self.directory_monitor_source)
    {
        dispatch_source_cancel(self.directory_monitor_source);
    }
    
    self.fileDescriptor = open([directory fileSystemRepresentation], O_EVTONLY);
    
    if (self.fileDescriptor < 0)
    {
        return;
    }
    
    self.directory_monitor_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, self.fileDescriptor, DISPATCH_VNODE_WRITE, self.directory_monitor_queue);
    
    if (self.directory_monitor_source == nil)
    {
        close(self.fileDescriptor);
    }
    
    dispatch_source_set_event_handler(self.directory_monitor_source, ^{
        if (!self.ignoreDirectoryContentChanges)
        {
            [self didDetectDirectoryChanges];
        }
    });
    
    dispatch_source_set_cancel_handler(self.directory_monitor_source, ^{
        close(self.fileDescriptor);
    });
    
    dispatch_resume(self.directory_monitor_source);
}

- (void)didDetectDirectoryChanges
{
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directory error:nil];
        
    NSSet *previousContentsSet = [NSSet setWithArray:self.previousContents];
    NSMutableSet *contentsSet = [NSMutableSet setWithArray:contents];
    
    [contentsSet minusSet:previousContentsSet];
    
    for (NSString *filename in contentsSet)
    {
        DLog(@"Monitoring new file %@", filename);
        [self monitorFileAtPath:[self.directory stringByAppendingPathComponent:filename]];
    }
    
    self.previousContents = contents;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RSTDirectoryMonitorContentsDidChangeNotification object:self];
}

- (void)monitorFileAtPath:(NSString *)filepath
{
    [self.unavailableFilesSet addObject:[filepath lastPathComponent]];
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
    unsigned long long fileSize = [attributes fileSize];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(compareFileSizeAtPathToPreviousFileSize:) userInfo:@{@"filepath": filepath, @"fileSize": @(fileSize)} repeats:NO];
        [timer setTolerance:1.0];
    });
}

- (void)compareFileSizeAtPathToPreviousFileSize:(NSTimer *)timer
{
    NSString *filepath = [timer userInfo][@"filepath"];
    unsigned long long previousFileSize = [[timer userInfo][@"fileSize"] unsignedLongLongValue];
    
    dispatch_async(self.directory_monitor_queue, ^{
        @autoreleasepool {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
            unsigned long long fileSize = [attributes fileSize];
            
            if (previousFileSize != fileSize)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(compareFileSizeAtPathToPreviousFileSize:) userInfo:@{@"filepath": filepath, @"fileSize": @(fileSize)} repeats:NO];
                    [timer setTolerance:1.0];
                });
                
                return;
            }
            
            NSLog(@"File is ready for reading!");
            
            [self.unavailableFilesSet removeObject:[filepath lastPathComponent]];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:RSTDirectoryMonitorContentsDidChangeNotification object:self];
        }
    });
}

#pragma mark - Public

- (NSArray *)availableFiles
{
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directory error:nil];
    
    NSMutableOrderedSet *contentsSet = [NSMutableOrderedSet orderedSetWithArray:contents];
    [contentsSet minusSet:self.unavailableFilesSet];
        
    return [contentsSet array];
}

- (NSArray *)unavailableFiles
{
    return [self.unavailableFilesSet allObjects];
}

- (NSArray *)allFiles
{
    return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directory error:nil];
}

#pragma mark - Getters/Setters

- (void)setIgnoreDirectoryContentChanges:(BOOL)ignoreDirectoryContentChanges
{
    if (_ignoreDirectoryContentChanges == ignoreDirectoryContentChanges)
    {
        return;
    }
    
    _ignoreDirectoryContentChanges = ignoreDirectoryContentChanges;
    
    if (!ignoreDirectoryContentChanges)
    {
        [self didDetectDirectoryChanges];
    }
}

@end
