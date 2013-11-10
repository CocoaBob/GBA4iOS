//
//  GBASyncManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GBAROM.h"

@interface GBASyncManager : NSObject

@property (readonly, strong, nonatomic) NSSet *conflictedROMs;

+ (instancetype)sharedManager;

- (void)start;
- (void)performInitialSync;
- (void)synchronize;
- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom;

@end
