//
//  GBASplitViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/28/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAROMTableViewController.h"
#import "GBAEmulationViewController.h"

@class GBASplitViewController;

@protocol GBASplitViewControllerEmulationDelegate <NSObject>

@optional
- (BOOL)splitViewControllerShouldResumeEmulation:(GBASplitViewController *)splitViewController;

@end

@interface GBASplitViewController : UISplitViewController

@property (readonly, assign, nonatomic) BOOL romTableViewControllerIsVisible;

@property (readonly, strong, nonatomic) GBAROMTableViewController *romTableViewController;
@property (readonly, strong, nonatomic) GBAEmulationViewController *emulationViewController;
@property (weak, nonatomic) id<GBASplitViewControllerEmulationDelegate> emulationDelegate;

- (void)showROMTableViewControllerWithAnimation:(BOOL)animated;
- (void)hideROMTableViewControllerWithAnimation:(BOOL)animated;

+ (instancetype)appropriateSplitViewController;

@end
