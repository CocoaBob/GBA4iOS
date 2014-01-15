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
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self.directory stringByAppendingPathComponent:filename] error:nil];
        unsigned long long size = [attributes fileSize];
        
        if (size == 0) // Being copied over
        {
            [self monitorFileAtPath:[self.directory stringByAppendingPathComponent:filename]];
        }
    }
    
    self.previousContents = contents;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RSTDirectoryMonitorContentsDidChangeNotification object:self];
}

- (void)monitorFileAtPath:(NSString *)filepath
{
    [self.unavailableFilesSet addObject:[filepath lastPathComponent]];
    
    int fileDescriptor = open([filepath fileSystemRepresentation], O_EVTONLY);
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fileDescriptor, DISPATCH_VNODE_ATTRIB, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    
    if (source == nil)
    {
        close(fileDescriptor);
    }
    
    dispatch_source_set_event_handler(source, ^{
        // You may think this line below doesn't do anything, but you'd be wrong. For WHATEVER reason, the lines of code that follow are never called unless the below line of code is called. WTF. Try it out, you'll be amazed.
        unsigned long data = dispatch_source_get_data(source);
        
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
        unsigned long long size = [attributes fileSize];
        
        if (size > 0)
        {
            // Built-in safety due to file ready detection not always being completely accurate
            [NSThread sleepForTimeInterval:1.0];
            
            NSLog(@"File is ready for reading!");
            
            [self.unavailableFilesSet removeObject:[filepath lastPathComponent]];
            
            dispatch_source_cancel(source);
            
            [[NSNotificationCenter defaultCenter] postNotificationName:RSTDirectoryMonitorContentsDidChangeNotification object:self];
        }
        
    });
    
    dispatch_source_set_cancel_handler(self.directory_monitor_source, ^{
        close(fileDescriptor);
    });
    
    dispatch_resume(source);
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

@end
