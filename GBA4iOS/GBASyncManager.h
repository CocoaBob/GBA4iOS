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


+ (instancetype)sharedManager;

- (void)start;
- (void)synchronize;
- (void)updateRemoteSaveFileForROM:(GBAROM *)rom;

@end
