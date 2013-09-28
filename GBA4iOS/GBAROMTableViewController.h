//
//  GBAROMTableViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <RSTFileBrowserViewController/RSTFileBrowserViewController.h>

typedef NS_ENUM(NSInteger, GBAROMTableViewControllerTheme)
{
    GBAROMTableViewControllerThemeOpaque = 0,
    GBAROMTableViewControllerThemeTranslucent = 1,
};

@interface GBAROMTableViewController : RSTFileBrowserViewController <UISplitViewControllerDelegate>

@end
