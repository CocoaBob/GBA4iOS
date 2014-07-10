//
//  GBASplitViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/28/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASplitViewController_Private.h"
#import "GBAClassicSplitViewController.h"
#import "GBASyncManager.h"

@interface GBAClassicSplitViewController () <UISplitViewControllerDelegate, GBAROMTableViewControllerAppearanceDelegate, UIPopoverControllerDelegate>

@property (assign, nonatomic) UIBarButtonItem *barButtonItem;

@property (assign, nonatomic, getter = isLoadingApplication) BOOL loadingApplication;
@property (assign, nonatomic, getter = isRotatingInterface) BOOL rotatingInterface;

@end

@implementation GBAClassicSplitViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.loadingApplication = YES;
        
        self.romTableViewControllerIsVisible = NO;
        
        self.romTableViewController = [[GBAROMTableViewController alloc] init];
        self.romTableViewController.appearanceDelegate = self;
        UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(self.romTableViewController);
        
        self.emulationViewController = [[GBAEmulationViewController alloc] init];
        
        self.viewControllers = @[navigationController, self.emulationViewController];
        
        self.delegate = self;
        self.presentsWithGesture = NO;
    }
    
    return self;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    self.rotatingInterface = YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    self.rotatingInterface = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ([self isLoadingApplication])
    {
        // Get a reference to the popover controller so we can prevent it from dismissing when there isn't a ROM loaded.
        UIPopoverController *popoverController = [self.romTableViewController.navigationController valueForKey:@"_popoverController"];
        popoverController.delegate = self;
        
        self.loadingApplication = NO;
    }
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
    // When rotating to the orientation 180 degress opposite of the current one (ex Landscape Left to Landscape Right), popover is dismissed and shown again. This prevents us from loading the ROM temporarily
    if (![self isRotatingInterface])
    {
        [self.emulationViewController blurWithInitialAlpha:0.0];
        [UIView animateWithDuration:0.2 animations:^{
            [self.emulationViewController setBlurAlpha:1.0];
        }];
    }
    
    self.romTableViewControllerIsVisible = YES;
}

- (void)romTableViewControllerWillDisappear:(GBAROMTableViewController *)romTableViewController
{
    // When rotating to the orientation 180 degress opposite of the current one (ex Landscape Left to Landscape Right), popover is dismissed and shown again. This prevents us from loading the ROM temporarily
    if (![self isRotatingInterface])
    {
        [UIView animateWithDuration:0.2 animations:^{
            [self.emulationViewController setBlurAlpha:0.0];
        } completion:^(BOOL finished) {
            [self.emulationViewController removeBlur];
        }];
        
        [[GBASyncManager sharedManager] setShouldShowSyncingStatus:NO];
        [self.emulationViewController resumeEmulation];
    }
    
    self.romTableViewControllerIsVisible = NO;
    
}

#pragma mark - UIPopoverControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    // Needs to "dismiss" popover when rotating to the orientation 180 degress opposite of the current one (ex Landscape Left to Landscape Right)
    if ([self isRotatingInterface])
    {
        return YES;
    }
    
    if ([self.emulationDelegate respondsToSelector:@selector(splitViewControllerShouldResumeEmulation:)])
    {
        return [self.emulationDelegate splitViewControllerShouldResumeEmulation:self];
    }
    
    return YES;
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
