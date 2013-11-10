//
//  GBASyncingDetailViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAROM.h"

@interface GBASyncingDetailViewController : UITableViewController

@property (readonly, strong, nonatomic) GBAROM *rom;

- (instancetype)initWithROM:(GBAROM *)rom;

@end
