//
//  GBAEmulationViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulationViewController.h"
#import "GBAEmulatorScreen.h"
#import "GBAController.h"
#import "GBAControllerView.h"
#import "UIImage+ImageEffects.h"
#import "GBASaveStateViewController.h"
#import "GBACheatManagerViewController.h"
#import "GBASettingsViewController.h"

#if !(TARGET_IPHONE_SIMULATOR)
#import "GBAEmulatorCore.h"
#endif

#import <RSTActionSheet/UIActionSheet+RSTAdditions.h>

//#define USE_INCLUDED_UI

static GBAEmulationViewController *_emulationViewController;

@interface GBAEmulationViewController () <GBAControllerViewDelegate, UIViewControllerTransitioningDelegate, GBASaveStateViewControllerDelegate> {
    CFAbsoluteTime _romStartTime;
    CFAbsoluteTime _romPauseTime;
    BOOL _hasPerformedInitialLayout;
}

@property (weak, nonatomic) IBOutlet GBAEmulatorScreen *emulatorScreen;
@property (strong, nonatomic) IBOutlet GBAControllerView *controllerView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *portraitBottomLayoutConstraint;
@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UIView *screenContainerView;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (copy, nonatomic) NSSet *buttonsToPressForNextCycle;
@property (strong, nonatomic) UIWindow *airplayWindow;

@property (nonatomic) CFTimeInterval previousTimestamp;
@property (nonatomic) NSInteger frameCount;
@property (weak, nonatomic) IBOutlet UILabel *framerateLabel;

// Sustaining Buttons
@property (assign, nonatomic) BOOL selectingSustainedButton;
@property (strong, nonatomic) NSMutableSet *sustainedButtonSet;

@property (assign, nonatomic) BOOL blurringContents;
@property (strong, nonatomic) UIImageView *blurredScreenImageView;
@property (strong, nonatomic) UIImageView *blurredControllerImageView;

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (instancetype)initWithROM:(GBAROM *)rom
{
    NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"GBAResources" ofType:@"bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:resourceBundle];
    self = [storyboard instantiateViewControllerWithIdentifier:@"emulationViewController"];
    if (self)
    {
        _emulationViewController = self;
        InstallUncaughtExceptionHandler();
        
        _rom = rom;
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] setRom:self.rom];
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
    GBAController *controller = [GBAController controllerWithContentsOfFile:self.skinFilepath];
    self.controllerView.controller = controller;
    self.controllerView.delegate = self;
    
    if ([[UIScreen screens] count] > 1)
    {
        UIScreen *newScreen = [UIScreen screens][1];
        [self setUpAirplayScreen:newScreen];
    }
    
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:GBASettingsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidConnect:) name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
    
    //[self.controller showButtonRects];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLink:)];
	[self.displayLink setFrameInterval:1];
	[self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self updateSettings:nil];
}

// called from viewDidLayoutSubviews
- (void)performInitialLayout
{    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.screenContainerView.bounds.size]];
#endif
    [self.emulatorScreen invalidateIntrinsicContentSize];
    
#if !(TARGET_IPHONE_SIMULATOR)
    self.emulatorScreen.eaglView = [GBAEmulatorCore sharedCore].eaglView;
#endif
    
    [self startEmulation];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!_hasPerformedInitialLayout)
    {
        [self performInitialLayout];
        _hasPerformedInitialLayout = YES;
    }
    
    if (![self.view respondsToSelector:@selector(setTintColor:)])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    if (self.presentedViewController)
    {
        self.emulationPaused = NO;
        [self resumeEmulation];
    }
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

#pragma mark - Private

- (void)handleDisplayLink:(CADisplayLink *)displayLink
{
    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    CFTimeInterval elapsed = now - self.previousTimestamp;
    self.frameCount++;
    
    if (elapsed > 1.0)
    {
        CGFloat fps = self.frameCount / elapsed;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.framerateLabel.text = [NSString stringWithFormat:@"%.f FPS", fps];
        });
        self.previousTimestamp = now;
        self.frameCount = 0;
    }
    
    if (self.buttonsToPressForNextCycle)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] pressButtons:self.buttonsToPressForNextCycle];
#endif
        
        self.buttonsToPressForNextCycle = nil;
    }
}

- (CGSize)screenSizeForContainerSize:(CGSize)containerSize
{
    CGSize resolution = CGSizeMake(240, 160); // GBA Resolution
    CGSize size = resolution;
    CGFloat widthScale = containerSize.width/resolution.width;
    CGFloat heightScale = containerSize.height/resolution.height;
    
    if (heightScale < widthScale)
    {
        // Use height scale to size to fit
        size = CGSizeMake(resolution.width * heightScale, resolution.height * heightScale);
    }
    else
    {
        // Use width scale to size to fit
        size = CGSizeMake(resolution.width * widthScale, resolution.height * widthScale);
    }
    
    return size;
}

#pragma mark - Airplay

- (void)screenDidConnect:(NSNotification *)notification
{
    if (self.airplayWindow)
    {
        return;
    }
    
    UIScreen *newScreen = [notification object];
    [self setUpAirplayScreen:newScreen];
}

- (void)screenDidDisconnect:(NSNotification *)notification
{
    if (self.airplayWindow == nil)
    {
        return;
    }
    
    [self tearDownAirplayScreen];
}

- (void)setUpAirplayScreen:(UIScreen *)screen
{
    CGRect screenBounds = screen.bounds;
    
    self.airplayWindow = ({
        UIWindow *window = [[UIWindow alloc] initWithFrame:screenBounds];
        window.screen = screen;
        window.hidden = NO;
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:screenBounds.size]];
#endif
        
        self.emulatorScreen.center = CGPointMake(roundf(screenBounds.size.width/2), roundf(screenBounds.size.height/2));
        
        [window addSubview:self.emulatorScreen];
        window;
    });
    
    [self.emulatorScreen invalidateIntrinsicContentSize];
}

- (void)tearDownAirplayScreen
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:self.contentView.bounds.size];
#endif
    [self.emulatorScreen invalidateIntrinsicContentSize];
    
    self.airplayWindow.hidden = YES;
    [self.screenContainerView addSubview:self.emulatorScreen];
    self.airplayWindow = nil;
    
    self.emulatorScreen.frame = ({
        CGRect frame = self.emulatorScreen.frame;
        frame.origin = CGPointZero;
        frame;
    });
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
    else if ([self.sustainedButtonSet intersectsSet:buttons]) // We re-pressed a sustained button, so we need to release it then press it in the next emulation CPU cycle
    {
        NSMutableSet *sustainedButtons = [self.sustainedButtonSet mutableCopy];
        [sustainedButtons intersectSet:buttons];
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] releaseButtons:sustainedButtons];
#endif
        
        NSMutableSet *buttonsWithoutSustainButtons = [buttons mutableCopy];
        [buttonsWithoutSustainButtons minusSet:self.sustainedButtonSet];
        
        self.buttonsToPressForNextCycle = buttons;
    }
    else
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] pressButtons:buttons];
#endif
    }
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
    
    self.emulationPaused = YES;
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
                self.emulationPaused = NO;
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
                self.emulationPaused = NO;
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
    
    self.emulationPaused = NO;
    [self resumeEmulation];
}

#pragma mark - Save States

- (void)presentSaveStateMenuWithMode:(GBASaveStateViewControllerMode)mode
{
    NSString *filename = self.rom.name;
    
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
    
    NSString *romName = self.rom.name;
    NSString *directory = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"Save States/%@", romName]];
    
    return directory;
}

#pragma mark - Cheats

- (void)presentCheatManager
{
    GBACheatManagerViewController *cheatManagerViewController = [[GBACheatManagerViewController alloc] initWithROM:self.rom];
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(cheatManagerViewController) animated:YES completion:nil];
}

#pragma mark - Settings

- (void)updateSettings:(NSNotification *)notification
{
    self.framerateLabel.hidden = ![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsShowFramerateKey];
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
        UIView *snapshotView = [self.controllerView snapshotViewAfterScreenUpdates:NO];
        snapshotView.frame = self.controllerView.frame;
        snapshotView.tag = ROTATION_SHAPSHOT_TAG;
        snapshotView.alpha = 1.0;
        
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
        {
            self.controllerView.alpha = 0.0;
            [self.contentView insertSubview:snapshotView belowSubview:self.controllerView];
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
        snapshotView.frame = self.controllerView.frame;
        
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
        {
            self.controllerView.alpha = 1.0;
        }
        
    }
    
    if (self.airplayWindow == nil)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.screenContainerView.bounds.size]];
        [self.emulatorScreen invalidateIntrinsicContentSize];
#endif
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
        self.controllerView.orientation = GBAControllerOrientationPortrait;
    }
    else
    {
        if ([[self.contentView constraints] containsObject:self.portraitBottomLayoutConstraint])
        {
            [self.contentView removeConstraint:self.portraitBottomLayoutConstraint];
        }
        self.controllerView.orientation = GBAControllerOrientationLandscape;
        [UIView performWithoutAnimation:^{
            self.controllerView.alpha = 0.5f;
        }];
    }
}

- (void)viewDidLayoutSubviews
{
    // possible iOS 7 bug? self.screenContainerView.bounds still has old bounds when this method is called, so we can't really do anything.
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
    [[GBAEmulatorCore sharedCore] startEmulation];
#endif
}

- (void)resumeEmulation
{
    if (!self.emulationPaused)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] resumeEmulation];
        [[GBAEmulatorCore sharedCore] pressButtons:self.sustainedButtonSet];
#endif
    }
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
        UIImage *blurredImage = [self blurredImageFromView:self.controllerView];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:blurredImage];
        [imageView sizeToFit];
        imageView.center = self.controllerView.center;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.alpha = alpha;
        [self.controllerView.superview addSubview:imageView];
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











