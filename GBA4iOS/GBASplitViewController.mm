//
//  GBASplitViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/28/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASplitViewController_Private.h"
#import "GBAClassicSplitViewController.h"
#import "GBAModernSplitViewController.h"

@implementation GBASplitViewController

+ (instancetype)appropriateSplitViewController
{
    GBASplitViewController *splitViewController = nil;
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1)
    {
        // iOS 7.1 or earlier
        splitViewController = [[GBAClassicSplitViewController alloc] initWithNibName:nil bundle:nil];
    }
    else
    {
        // iOS 8 or later
        splitViewController = [[GBAModernSplitViewController alloc] initWithNibName:nil bundle:nil];
    }
    
    return splitViewController;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return [self.emulationViewController shouldAutorotate];
}

#pragma mark - Subclass override

- (void)showROMTableViewControllerWithAnimation:(BOOL)animated
{
    // Subclasses override
}

- (void)hideROMTableViewControllerWithAnimation:(BOOL)animated
{
    // Subclasses override
}

@end
