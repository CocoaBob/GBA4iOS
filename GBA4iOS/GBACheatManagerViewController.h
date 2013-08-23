//
//  GBACheatManagerViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBACheat.h"
#import "GBAROM.h"

@class GBACheatManagerViewController;

@interface GBACheatManagerViewController : UITableViewController

@property (readonly, copy, nonatomic) GBAROM *rom;

- (instancetype)initWithROM:(GBAROM *)rom;

@end
