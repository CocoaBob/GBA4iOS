//
//  GBAWebBrowserHomepageViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/2/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GBAWebBrowserHomepage)
{
    GBAWebBrowserHomepageCustom       = -1,
    GBAWebBrowserHomepageGoogle       = 0,
    GBAWebBrowserHomepageYahoo        = 1,
    GBAWebBrowserHomepageBing         = 2,
    GBAWebBrowserHomepageGameFAQs     = 3,
    GBAWebBrowserHomepageSuperCheats  = 4,
};

@interface GBAWebBrowserHomepageViewController : UITableViewController

+ (NSString *)localizedNameForWebBrowserHomepage:(GBAWebBrowserHomepage)webBrowserHomepage;

@end
