//
//  GBASyncOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncOperation_Private.h"
#import "GBASyncManager_Private.h"

@interface GBASyncOperation ()

@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

@end

@implementation GBASyncOperation

#pragma mark - NSOperation

- (id)init
{
    self = [super init];
    if (self == nil)
    {
        return nil;
    }
    
    _isExecuting = NO;
    _isFinished = NO;
    
    _backgroundTaskIdentifier = rst_begin_background_task();
    
    _ugh_dropbox_requiring_main_thread_dispatch_queue = dispatch_queue_create("com.GBA4iOS.ugh_dropbox_requiring_main_thread_dispatch_queue", DISPATCH_QUEUE_CONCURRENT);
    
    rst_dispatch_sync_on_main_thread(^{
        _toastView = [RSTToastView toastViewWithMessage:nil];
    });
    
    return self;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (void)start
{
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    });
    
    [self beginSyncOperation];
}

- (void)finish
{
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = NO;
    [self didChangeValueForKey:@"isExecuting"];
    
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = YES;
    [self didChangeValueForKey:@"isFinished"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    });
    
    rst_end_background_task(_backgroundTaskIdentifier);
}

#pragma mark - Perform Operation

- (void)beginSyncOperation
{
    // Override in subclasses
}

#pragma mark - Public

- (void)showToastViewWithMessage:(NSString *)message forDuration:(NSTimeInterval)duration showActivityIndicator:(BOOL)showActivityIndicator
{
    rst_dispatch_sync_on_main_thread(^{
        self.toastView.showsActivityIndicator = showActivityIndicator;
        self.toastView.message = message;
        
        if (![self.toastView isVisible])
        {
            if ([self.delegate respondsToSelector:@selector(syncOperation:shouldShowToastView:)] && [self.delegate syncOperation:self shouldShowToastView:self.toastView])
            {
                [self.toastView showForDuration:duration];
            }
        }
    });
}

#pragma mark - Helper Methods

- (BOOL)romExistsWithName:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(pathExtension.lowercaseString == 'gba') OR (pathExtension.lowercaseString == 'gbc') OR (pathExtension.lowercaseString == 'gb')"];
    NSMutableArray *contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil] mutableCopy];
    [contents filterUsingPredicate:predicate];
    
    for (NSString *filename in contents)
    {
        if ([[filename stringByDeletingPathExtension] isEqualToString:name])
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Getters/Setters

- (DBUserClient *)restClient
{
    if (_restClient == nil)
    {
        _restClient = [DBClientsManager authorizedClient];
    }
    
    return _restClient;
}

@end
