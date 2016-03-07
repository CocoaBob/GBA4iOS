//
//  GBAModernSplitViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/9/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASplitViewController_Private.h"
#import "GBAModernSplitViewController.h"
#import "GBASyncManager.h"
#import "GBAMasterNavigationController.h"

@interface GBAModernSplitViewController () <UISplitViewControllerDelegate, UIPopoverControllerDelegate>

@end

@implementation GBAModernSplitViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.romTableViewControllerIsVisible = NO;
        
        self.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryOverlay;
        
        self.romTableViewController = [[GBAROMTableViewController alloc] initWithNibName:nil bundle:nil];
        self.emulationViewController = [[GBAEmulationViewController alloc] init];
        
        GBAMasterNavigationController *navigationController = [[GBAMasterNavigationController alloc] initWithRootViewController:self.romTableViewController];
        
        self.viewControllers = @[navigationController, self.emulationViewController];
        
        self.presentsWithGesture = NO;
        self.delegate = self;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    UIPopoverController *popoverController = [self.romTableViewController.navigationController valueForKey:@"_popoverController"];
    popoverController.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - UISplitViewControllerDelegate

// Will be right back, I'm going to shave for Alyssa

- (void)splitViewController:(UISplitViewController *)svc willChangeToDisplayMode:(UISplitViewControllerDisplayMode)displayMode
{
    if (displayMode == UISplitViewControllerDisplayModePrimaryOverlay)
    {
        [self.emulationViewController blurWithInitialAlpha:0.0];
        [UIView animateWithDuration:0.2 animations:^{
            [self.emulationViewController setBlurAlpha:1.0];
        }];
        
        self.romTableViewControllerIsVisible = YES;
    }
    else
    {
        [UIView animateWithDuration:0.2 animations:^{
            [self.emulationViewController setBlurAlpha:0.0];
        } completion:^(BOOL finished) {
            [self.emulationViewController removeBlur];
        }];
        
        [[GBASyncManager sharedManager] setShouldShowSyncingStatus:NO];
        [self.emulationViewController resumeEmulation];
        
        self.romTableViewControllerIsVisible = NO;
    }
}

#pragma mark - Public

- (void)showROMTableViewControllerWithAnimation:(BOOL)animated
{
    // dispatch_async so animation doesn't cause layout of emulation view controller to animate as well
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 delay:0 options:0 animations:^{
            self.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryOverlay;
        } completion:nil];
    });
}

- (void)hideROMTableViewControllerWithAnimation:(BOOL)animated
{
     // dispatch_async so animation doesn't cause layout of emulation view controller to animate as well
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 delay:0 options:0 animations:^{
            self.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryHidden;
        } completion:nil];
    });
}

#pragma mark - UIPopoverControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    if ([self.emulationDelegate respondsToSelector:@selector(splitViewControllerShouldResumeEmulation:)])
    {
        return [self.emulationDelegate splitViewControllerShouldResumeEmulation:self];
    }
    
    return YES;
}

@end
