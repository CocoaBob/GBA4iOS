//
//  GBAModernSplitViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/9/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASplitViewController_Private.h"
#import "GBAModernSplitViewController.h"

@interface GBAModernSplitViewController () <GBAROMTableViewControllerAppearanceDelegate>

@end

@implementation GBAModernSplitViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.romTableViewControllerIsVisible = NO;
        
        self.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryOverlay;
        
        self.romTableViewController = [[GBAROMTableViewController alloc] init];
        self.romTableViewController.appearanceDelegate = self;
        
        self.emulationViewController = [[GBAEmulationViewController alloc] init];
        
        self.viewControllers = @[RST_CONTAIN_IN_NAVIGATION_CONTROLLER(self.romTableViewController), self.emulationViewController];
        
        self.presentsWithGesture = NO;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


@end
