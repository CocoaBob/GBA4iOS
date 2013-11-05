//
//  GBASyncManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GBASyncManager : NSObject

@property (readonly, strong, nonatomic) NSSet *conflictedFiles;

+ (instancetype)sharedManager;

- (void)start;
- (void)synchronize;
- (void)updateRemoteFileWithFileAtPath:(NSString *)path;

@end
