//
//  GBASyncManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>

#import "GBAROM_Private.h"

extern NSString *const GBAFileDeviceName;

@interface GBASyncManager : NSObject

+ (instancetype)sharedManager;

- (void)start;
- (void)performInitialSync;
- (void)synchronize;
- (void)prepareToUploadSaveFileForROM:(GBAROM *)rom;

@end
