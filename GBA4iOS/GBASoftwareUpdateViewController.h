//
//  GBASoftwareUpdateViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 2/10/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GBASoftwareUpdate;

@interface GBASoftwareUpdateViewController : UITableViewController

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)controller;
+ (instancetype)controllerWithSoftwareUpdate:(GBASoftwareUpdate *)softwareUpdate;

@end
