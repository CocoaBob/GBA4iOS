//
//  RSTDirectoryMonitor.h
//
//  Created by Riley Testut on 7/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//
//

#import <Foundation/Foundation.h>

static NSString *RSTDirectoryMonitorContentsDidChangeNotification = @"RSTDirectoryMonitorContentsDidChangeNotification";

@interface RSTDirectoryMonitor : NSObject

// Directory being watched for changes.
@property (copy, nonatomic) NSString *directory;
@property (assign, nonatomic) BOOL ignoreDirectoryContentChanges;

@property (readonly, nonatomic) NSArray *availableFiles;
@property (readonly, nonatomic) NSArray *unavailableFiles;
@property (readonly, nonatomic) NSArray *allFiles;

- (instancetype)initWithDirectory:(NSString *)directory;

@end
