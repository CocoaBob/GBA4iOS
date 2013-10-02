//
//  GBASplitViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/28/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASplitViewController.h"

@interface GBASplitViewController () <UISplitViewControllerDelegate>

@property (readwrite, assign, nonatomic) BOOL romTableViewControllerHidden;
@property (assign, nonatomic) UIBarButtonItem *barButtonItem;

@end

@implementation GBASplitViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        _romTableViewControllerHidden = YES;
        
        _romTableViewController = [[GBAROMTableViewController alloc] init];
        UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(_romTableViewController);
        
        _emulationViewController = [[GBAEmulationViewController alloc] initWithROM:nil];
        
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

#pragma mark - Public

- (void)showROMTableViewControllerWithAnimation:(BOOL)animated
{
    if (animated)
    {
        [self setRomTableViewControllerHidden:NO];
    }
    else
    {
        [UIView performWithoutAnimation:^{
            [self setRomTableViewControllerHidden:NO];
        }];
    }
}

- (void)hideROMTableViewControllerWithAnimation:(BOOL)animated
{
    if (animated)
    {
        [self setRomTableViewControllerHidden:YES];
    }
    else
    {
        [UIView performWithoutAnimation:^{
            [self setRomTableViewControllerHidden:YES];
        }];
    }
}

- (void)setRomTableViewControllerHidden:(BOOL)romTableViewControllerHidden
{
    if (_romTableViewControllerHidden == romTableViewControllerHidden)
    {
        return;
    }
    
    _romTableViewControllerHidden = romTableViewControllerHidden;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    [self.barButtonItem.target performSelector:self.barButtonItem.action withObject:self.barButtonItem];
    
#pragma clang diagnostic pop
    
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
