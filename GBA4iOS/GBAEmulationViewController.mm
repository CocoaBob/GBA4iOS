//
//  GBAEmulationViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulationViewController.h"
#import "GBAEmulatorCore.h"
#import "GBAEmulatorScreen.h"
#import "GBAController.h"
#import "UIImage+ImageEffects.h"

#import <RSTActionSheet/UIActionSheet+RSTAdditions.h>

//#define USE_INCLUDED_UI

@interface GBAEmulationViewController () <GBAControllerDelegate>

@property (weak, nonatomic) IBOutlet GBAEmulatorScreen *emulatorScreen;
@property (strong, nonatomic) IBOutlet GBAController *controller;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *portraitBottomLayoutConstraint;
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UIView *screenContainerView;

@property (assign, nonatomic) BOOL blurringContents;
@property (strong, nonatomic) UIImageView *blurredScreenImageView;
@property (strong, nonatomic) UIImageView *blurredControllerImageView;

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (instancetype)initWithROMFilepath:(NSString *)romFilepath
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"emulationViewController"];
    if (self)
    {
        _romFilepath = [romFilepath copy];
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] setRomFilepath:romFilepath];
#endif
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#if !(TARGET_IPHONE_SIMULATOR)
    self.emulatorScreen.backgroundColor = [UIColor blackColor]; // It's set to blue in the storyboard for easier visual debugging
#endif
    
    self.controller.skinFilepath = self.skinFilepath;
    self.controller.delegate = self;
    
#if !(TARGET_IPHONE_SIMULATOR)
    self.emulatorScreen.eaglView = [GBAEmulatorCore sharedCore].eaglView;
#endif
    
    [self startEmulation];
    
#ifdef USE_INCLUDED_UI
    
    self.controller.hidden = YES;
    self.emulatorScreen.clipsToBounds = NO;
    [self.contentView addSubview:self.emulatorScreen];
    self.emulatorScreen.frame = ({
        CGRect frame = self.emulatorScreen.frame;
        frame.origin.y = 0;
        frame;
    });
    self.emulatorScreen.backgroundColor = [UIColor redColor];
    
#endif
    
    //[self.controller showButtonRects];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (![self.view respondsToSelector:@selector(setTintColor:)])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (![self.view respondsToSelector:@selector(setTintColor:)])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - Controls

- (void)controller:(GBAController *)controller didPressButtons:(NSSet *)buttons
{
    [[GBAEmulatorCore sharedCore] pressButtons:buttons];
}

- (void)controller:(GBAController *)controller didReleaseButtons:(NSSet *)buttons
{
    [[GBAEmulatorCore sharedCore] releaseButtons:buttons];
}

extern void restoreMenuFromGame();

- (void)controllerDidPressMenuButton:(GBAController *)controller
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] pauseEmulation];
#endif
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                               destructiveButtonTitle:NSLocalizedString(@"Return To Menu", @"")
                                                    otherButtonTitles:NSLocalizedString(@"Fast Forward", @""), NSLocalizedString(@"Save State", @""), NSLocalizedString(@"Load State", @""), NSLocalizedString(@"Cheats", @""), nil];
    [actionSheet showInView:self.view completion:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
        }
        else {
#if !(TARGET_IPHONE_SIMULATOR)
            [[GBAEmulatorCore sharedCore] resumeEmulation];
#endif
        }
    }];
}

#pragma mark - Layout

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#define ROTATION_SHAPSHOT_TAG 13

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if ([self.view respondsToSelector:@selector(snapshotViewAfterScreenUpdates:)] && (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) != UIInterfaceOrientationIsPortrait(toInterfaceOrientation)))
    {
        UIView *snapshotView = [self.controller snapshotViewAfterScreenUpdates:NO];
        snapshotView.frame = self.controller.frame;
        snapshotView.tag = ROTATION_SHAPSHOT_TAG;
        snapshotView.alpha = 1.0;
        
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
        {
            self.controller.alpha = 0.0;
            [self.contentView insertSubview:snapshotView belowSubview:self.controller];
        }
        else
        {
            [self.contentView addSubview:snapshotView];
        }
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if ([self.view respondsToSelector:@selector(snapshotViewAfterScreenUpdates:)])
    {
        UIView *snapshotView = [self.view viewWithTag:ROTATION_SHAPSHOT_TAG];
        snapshotView.alpha = 0.0;
        snapshotView.frame = self.controller.frame;
        
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
        {
            self.controller.alpha = 1.0;
        }
        
    }
    
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if ([self.view respondsToSelector:@selector(snapshotViewAfterScreenUpdates:)])
    {
        UIView *snapshotView = [self.view viewWithTag:ROTATION_SHAPSHOT_TAG];
        [snapshotView removeFromSuperview];
    }
}

- (void)viewWillLayoutSubviews
{    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        if ([[self.contentView constraints] containsObject:self.portraitBottomLayoutConstraint] == NO)
        {
            
            [self.contentView addConstraint:self.portraitBottomLayoutConstraint];
        }
        self.controller.orientation = GBAControllerOrientationPortrait;
    }
    else
    {
        if ([[self.contentView constraints] containsObject:self.portraitBottomLayoutConstraint])
        {
            [self.contentView removeConstraint:self.portraitBottomLayoutConstraint];
        }
        self.controller.orientation = GBAControllerOrientationLandscape;
        [UIView performWithoutAnimation:^{
            self.controller.alpha = 0.5f;
        }];
    }
}

#ifdef USE_INCLUDED_UI

#pragma mark - Included UI

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.emulatorScreen.eaglView touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.emulatorScreen.eaglView touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.emulatorScreen.eaglView touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.emulatorScreen.eaglView touchesEnded:touches withEvent:event];
}

#endif

#pragma mark - Emulation

- (void)startEmulation
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] startEmulation];
#endif
}

#pragma mark - Blurring

- (void)blurWithInitialAlpha:(CGFloat)alpha
{
    self.blurredScreenImageView = ({
        UIImage *blurredImage = [self blurredImageFromView:self.screenContainerView];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:blurredImage];
        [imageView sizeToFit];
        imageView.center = self.emulatorScreen.center;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.alpha = alpha;
        [self.screenContainerView.superview addSubview:imageView];
        imageView;
    });
    
    self.blurredControllerImageView = ({
        UIImage *blurredImage = [self blurredImageFromView:self.controller];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:blurredImage];
        [imageView sizeToFit];
        imageView.center = self.controller.center;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.alpha = alpha;
        [self.controller.superview addSubview:imageView];
        imageView;
    });
    
    self.blurringContents = YES;
}

- (void)removeBlur
{
    self.blurringContents = NO;
    
    [self.blurredControllerImageView removeFromSuperview];
    self.blurredControllerImageView = nil;
    
    [self.blurredScreenImageView removeFromSuperview];
    self.blurredScreenImageView = nil;
}

- (void)setBlurAlpha:(CGFloat)blurAlpha
{
    _blurAlpha = blurAlpha;
    self.blurredScreenImageView.alpha = blurAlpha;
    self.blurredControllerImageView.alpha = blurAlpha;
}

- (UIImage *)blurredImageFromView:(UIView *)view
{
    CGFloat edgeExtension = 10;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(view.bounds.size.width + edgeExtension * 2, view.bounds.size.height + edgeExtension * 2), YES, [[UIScreen mainScreen] scale]);
    [view drawViewHierarchyInRect:CGRectMake(edgeExtension, edgeExtension, CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds)) afterScreenUpdates:NO];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIColor *tintColor = [UIColor colorWithWhite:0.11 alpha:0.73];
    return [image applyBlurWithRadius:10 tintColor:tintColor saturationDeltaFactor:1.8 maskImage:nil];
}











@end











