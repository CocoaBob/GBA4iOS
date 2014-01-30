//
//  GBAROM_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROM.h"

extern NSString *const GBAROMConflictedStateChangedNotification;
extern NSString *const GBAROMSyncingDisabledStateChangedNotification;

@interface GBAROM ()

@property (readonly, assign, nonatomic) BOOL usesGBCRTC;

@property (readwrite, assign, nonatomic) BOOL syncingDisabled;
@property (readwrite, assign, nonatomic) BOOL conflicted;
@property (readwrite, assign, nonatomic) BOOL newlyConflicted;

@property (readwrite, strong, nonatomic) GBAEvent *event;

@end
