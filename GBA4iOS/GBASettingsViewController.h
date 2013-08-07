//
//  GBASettingsViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const GBASettingsDidChangeNotification;

@interface GBASettingsViewController : UITableViewController

+ (void)registerDefaults;

@end
