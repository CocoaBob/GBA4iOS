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
#import "GBASaveStateViewController.h"
#import "GBACheatManagerViewController.h"

#import <RSTActionSheet/UIActionSheet+RSTAdditions.h>

//#define USE_INCLUDED_UI

static GBAEmulationViewController *_emulationViewController;

@interface GBAEmulationViewController () <GBAControllerDelegate, UIViewControllerTransitioningDelegate, GBASaveStateViewControllerDelegate, GBACheatManagerViewControllerDelegate> {
    CFAbsoluteTime _romStartTime;
    CFAbsoluteTime _romPauseTime;
}

@property (weak, nonatomic) IBOutlet GBAEmulatorScreen *emulatorScreen;
@property (strong, nonatomic) IBOutlet GBAController *controller;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *portraitBottomLayoutConstraint;
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UIView *screenContainerView;

// Sustaining Buttons
@property (assign, nonatomic) BOOL selectingSustainedButton;
@property (strong, nonatomic) NSMutableSet *sustainedButtonSet;

@property (assign, nonatomic) BOOL blurringContents;
@property (strong, nonatomic) UIImageView *blurredScreenImageView;
@property (strong, nonatomic) UIImageView *blurredControllerImageView;

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (instancetype)initWithROMFilepath:(NSString *)romFilepath
{
    NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"GBAResources" ofType:@"bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:resourceBundle];
    self = [storyboard instantiateViewControllerWithIdentifier:@"emulationViewController"];
    if (self)
    {
        _emulationViewController = self;
        InstallUncaughtExceptionHandler();
        
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
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
    
    [self resumeEmulation];
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
    if (self.selectingSustainedButton)
    {
        // Release previous sustained buttons
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] releaseButtons:self.sustainedButtonSet];
#endif
        
        self.sustainedButtonSet = [buttons mutableCopy];
        [self exitSustainButtonSelectionMode];
    }
    else
    {
        // If the user re-taps a sustained button, we remove it from the sustainedButtonSet
        [self.sustainedButtonSet minusSet:buttons];
    }
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] pressButtons:buttons];
#endif
}

- (void)controller:(GBAController *)controller didReleaseButtons:(NSSet *)buttons
{
    if (self.sustainedButtonSet)
    {
        NSMutableSet *set = [buttons mutableCopy];
        [set minusSet:self.sustainedButtonSet];
        buttons = set;
    }
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] releaseButtons:buttons];
#endif
}

#pragma mark - Pause Menu

- (void)controllerDidPressMenuButton:(GBAController *)controller
{
    _romPauseTime = CFAbsoluteTimeGetCurrent();
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] pauseEmulation];
#endif
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                               destructiveButtonTitle:NSLocalizedString(@"Return To Menu", @"")
                                                    otherButtonTitles:
                                  NSLocalizedString(@"Fast Forward", @""),
                                  NSLocalizedString(@"Save State", @""),
                                  NSLocalizedString(@"Load State", @""),
                                  NSLocalizedString(@"Cheat Codes", @""),
                                  NSLocalizedString(@"Sustain Button", @""), nil];
    
    [actionSheet showInView:self.view selectionHandler:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            [self dismissEmulationViewController];
            [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
        }
        else {
            //buttonIndex = buttonIndex; // Reserved for later change
            if (buttonIndex == 1)
            {
                [self resumeEmulation];
            }
            if (buttonIndex == 2)
            {
                [self presentSaveStateMenuWithMode:GBASaveStateViewControllerModeSaving];
            }
            else if (buttonIndex == 3)
            {
                [self presentSaveStateMenuWithMode:GBASaveStateViewControllerModeLoading];
            }
            else if (buttonIndex == 4)
            {
                [self presentCheatManager];
            }
            else if (buttonIndex == 5)
            {
                [self enterSustainButtonSelectionMode];
            }
            else {
                [self resumeEmulation];
            }
        }
    }];
}

- (void)enterSustainButtonSelectionMode
{
    self.selectingSustainedButton = YES;
}

- (void)exitSustainButtonSelectionMode
{
    self.selectingSustainedButton = NO;
    
    [self resumeEmulation];
}

#pragma mark - Save States

- (void)presentSaveStateMenuWithMode:(GBASaveStateViewControllerMode)mode
{
    NSString *filename = [self.romFilepath lastPathComponent];
    filename = [filename stringByDeletingPathExtension];
    
    GBASaveStateViewController *saveStateViewController = [[GBASaveStateViewController alloc] initWithSaveStateDirectory:[self saveStateDirectory] mode:mode];
    saveStateViewController.delegate = self;
    saveStateViewController.modalPresentationStyle = UIModalPresentationCustom;
    saveStateViewController.transitioningDelegate = self;
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(saveStateViewController) animated:YES completion:nil];
}

- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController willLoadStateFromPath:(NSString *)filepath
{
    if ([[filepath lastPathComponent] hasPrefix:@"autosave"] && [self shouldAutosave])
    {
        NSString *backupFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"backup.sgm"];
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] saveStateToFilepath:backupFilepath];
#endif
    }
    else
    {
        if ([self shouldAutosave])
        {
            [self updateAutosaveState];
        }
    }
}

- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController didLoadStateFromPath:(NSString *)filepath
{
    if ([[filepath lastPathComponent] hasPrefix:@"autosave"] && [self shouldAutosave])
    {
        NSString *autosaveFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"autosave.sgm"];
        NSString *backupFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"backup.sgm"];
        
        [[NSFileManager defaultManager] replaceItemAtURL:[NSURL fileURLWithPath:autosaveFilepath] withItemAtURL:[NSURL fileURLWithPath:backupFilepath] backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:nil error:nil];
    }
}

void InstallUncaughtExceptionHandler()
{
	NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
	signal(SIGABRT, SignalHandler);
	signal(SIGILL, SignalHandler);
	signal(SIGSEGV, SignalHandler);
	signal(SIGFPE, SignalHandler);
	signal(SIGBUS, SignalHandler);
	signal(SIGPIPE, SignalHandler);
}

void SignalHandler(int signal)
{
    [_emulationViewController handleException];
}

void uncaughtExceptionHandler(NSException *exception)
{
    [_emulationViewController handleException];
}

- (void)handleException
{
    if ([self shouldAutosave]) {
        [self updateAutosaveState];
    }
}

- (BOOL)shouldAutosave
{
    // If the user loads a save state in the first 3 seconds, the autosave would probably be useless to them as it would take them back to the title screen of their game
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"autosave"] && (_romPauseTime - _romStartTime >= 3.0f);
}

- (void)updateAutosaveState
{
    NSString *autosaveFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"autosave.sgm"];
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] saveStateToFilepath:autosaveFilepath];
#endif
}

- (NSString *)saveStateDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *romName = [[self.romFilepath lastPathComponent] stringByDeletingPathExtension];
    NSString *directory = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"Save States/%@", romName]];
    
    return directory;
}

#pragma mark - Cheats

- (void)presentCheatManager
{
    GBACheatManagerViewController *cheatManagerViewController = [[GBACheatManagerViewController alloc] initWithCheatsDirectory:[self cheatsDirectory]];
    cheatManagerViewController.delegate = self;
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(cheatManagerViewController) animated:YES completion:nil];
}

- (NSString *)cheatsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *romName = [[self.romFilepath lastPathComponent] stringByDeletingPathExtension];
    NSString *directory = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"Cheats/%@", romName]];
    
    return directory;
}

#pragma mark GBACheatManagerViewControllerDelegate

- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController didAddCheat:(GBACheat *)cheat
{
    [[GBAEmulatorCore sharedCore] addCheat:cheat];
}

- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController didEnableCheat:(GBACheat *)cheat atIndex:(NSInteger)index
{
    [[GBAEmulatorCore sharedCore] enableCheatAtIndex:index];
}

- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController didDisableCheat:(GBACheat *)cheat atIndex:(NSInteger)index
{
    [[GBAEmulatorCore sharedCore] disableCheatAtIndex:index];
}

#pragma mark - Presenting/Dismissing

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return nil;
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    
    return nil;
}

- (void)dismissEmulationViewController
{
    if ([self shouldAutosave])
    {
        [self updateAutosaveState];
    }
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - App Status

- (void)willResignActive:(NSNotification *)notification
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] pauseEmulation];
#endif
}

- (void)didBecomeActive:(NSNotification *)notification
{
    [self resumeEmulation];
}

- (void)didEnterBackground:(NSNotification *)notification
{
    if ([self shouldAutosave])
    {
        [self updateAutosaveState];
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] prepareToEnterBackground];
#endif
}

- (void)willEnterForeground:(NSNotification *)notification
{
    // Nothing foreground specific, everything handled in didBecomeActive
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
    _romStartTime = CFAbsoluteTimeGetCurrent();
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] setCheatsDirectory:[self cheatsDirectory]];
    [[GBAEmulatorCore sharedCore] startEmulation];
#endif
}

- (void)resumeEmulation
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] resumeEmulation];
    [[GBAEmulatorCore sharedCore] pressButtons:self.sustainedButtonSet];
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











