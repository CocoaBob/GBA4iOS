//
//  GBASyncOperation_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncOperation.h"

@interface GBASyncOperation () <GBASyncOperationDelegate>

@property (strong, nonatomic) DBUserClient *restClient;
@property (strong, nonatomic) dispatch_queue_t ugh_dropbox_requiring_main_thread_dispatch_queue;

- (void)beginSyncOperation;
- (void)finish;

- (void)showToastViewWithMessage:(NSString *)message forDuration:(NSTimeInterval)duration showActivityIndicator:(BOOL)showActivityIndicator;


@end
