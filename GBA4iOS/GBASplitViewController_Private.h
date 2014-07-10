//
//  GBASplitViewController_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/9/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASplitViewController.h"

@interface GBASplitViewController ()

@property (readwrite, assign, nonatomic) BOOL romTableViewControllerIsVisible;

@property (readwrite, strong, nonatomic) GBAROMTableViewController *romTableViewController;
@property (readwrite, strong, nonatomic) GBAEmulationViewController *emulationViewController;

@end