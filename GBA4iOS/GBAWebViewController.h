//
//  GBAWebViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/26/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "RSTWebViewController.h"

#import "GBAROM.h"

@interface GBAWebViewController : RSTWebViewController

@property (readonly, assign, nonatomic) GBAROMType romType;

- (instancetype)initWithROMType:(GBAROMType)romType;

@end
