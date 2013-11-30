//
//  GBASplitViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/28/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASplitViewController.h"
#import "GBASyncManager.h"

@interface GBASplitViewController () <UISplitViewControllerDelegate, GBAROMTableViewControllerAppearanceDelegate>

@property (readwrite, assign, nonatomic) BOOL romTableViewControllerIsVisible;
@property (assign, nonatomic) UIBarButtonItem *barButtonItem;

@end

@implementation GBASplitViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        _romTableViewControllerIsVisible = NO;
        
        _romTableViewController = [[GBAROMTableViewController alloc] init];
        _romTableViewController.appearanceDelegate = self;
        UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(_romTableViewController);
        
        _emulationViewController = [[GBAEmulationViewController alloc] init];
        
        self.viewControllers = @[navigationController, _emulationViewController];
        
        self.delegate = self;
        self.presentsWithGesture = NO;
    }
    
    return self;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return [self.emulationViewController shouldAutorotate];
}

#pragma mark - Public

- (void)showROMTableViewControllerWithAnimation:(BOOL)animated
{
    if ([self romTableViewControllerIsVisible])
    {
        return;
    }
    
    if (animated)
    {
        [self showHideROMTableViewController];
    }
    else
    {
        [UIView performWithoutAnimation:^{
            [self showHideROMTableViewController];
        }];
    }
}

- (void)hideROMTableViewControllerWithAnimation:(BOOL)animated
{
    if (![self romTableViewControllerIsVisible])
    {
        return;
    }
    
    if (animated)
    {
        [self showHideROMTableViewController];
    }
    else
    {
        [UIView performWithoutAnimation:^{
            [self showHideROMTableViewController];
        }];
    }
}

#pragma mark - Private

- (void)showHideROMTableViewController
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    [self.barButtonItem.target performSelector:self.barButtonItem.action withObject:self.barButtonItem];
    
#pragma clang diagnostic pop
    
}

#pragma mark - GBAROMTableViewControllerAppearanceDelegate

- (void)romTableViewControllerWillAppear:(GBAROMTableViewController *)romTableViewController
{
    [self.emulationViewController blurWithInitialAlpha:0.0];
    [UIView animateWithDuration:0.2 animations:^{
        [self.emulationViewController setBlurAlpha:1.0];
    }];
    
    self.romTableViewControllerIsVisible = YES;
}

- (void)romTableViewControllerWillDisappear:(GBAROMTableViewController *)romTableViewController
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

#pragma mark - UISplitViewControllerDelegate

- (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    return YES;
}

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc
{
    self.barButtonItem = barButtonItem;
}

@end
