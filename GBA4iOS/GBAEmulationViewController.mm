//
//  GBAEmulationViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulationViewController.h"
#import "GBAEmulatorScreen.h"
#import "GBAControllerSkin.h"
#import "GBAControllerView.h"
#import "UIImage+ImageEffects.h"
#import "GBASaveStateViewController.h"
#import "GBACheatManagerViewController.h"
#import "GBASettingsViewController.h"
#import "GBASplitViewController.h"
#import "GBAROMTableViewControllerAnimator.h"
#import "GBAInitialPresentROMTableViewControllerAnimator.h"
#import "GBAPresentOverlayViewControllerAnimator.h"
#import "GBASyncManager.h"
#import "UIScreen+Size.h"
#import "GBAExternalController.h"
#import "GBASyncingDetailViewController.h"
#import "GBAAppDelegate.h"
#import "GBAEventDistributionViewController.h"
#import "GBAKeyboardDismissalNavigationController.h"

#import <GameController/GameController.h>
#import <AVFoundation/AVFoundation.h>

#import "GBAEmulatorCore.h"
#import "GBALinkManager.h"
#import "GBABluetoothLinkManager.h"

#import "UIActionSheet+RSTAdditions.h"
#import "UIAlertView+RSTAdditions.h"
#include <sys/sysctl.h>

static GBAEmulationViewController *_emulationViewController;

@interface GBAEmulationViewController () <GBAControllerInputDelegate, UIViewControllerTransitioningDelegate, GBASaveStateViewControllerDelegate, GBACheatManagerViewControllerDelegate, GBASyncingDetailViewControllerDelegate, GBAEventDistributionViewControllerDelegate, GBAEmulatorCoreDelegate, GBAROMTableViewControllerAppearanceDelegate> {
    CFAbsoluteTime _romStartTime;
    CFAbsoluteTime _romPauseTime;
    
    NSInteger _sustainButtonFrameCount;
    NSInteger _hideIntroAnimationFrameCount;
}

@property (weak, nonatomic) IBOutlet GBAEmulatorScreen *emulatorScreen;
@property (strong, nonatomic) IBOutlet GBAControllerView *controllerView;
@property (strong, nonatomic) GBAExternalController *externalController;
@property (strong, nonatomic) UIActionSheet *pausedActionSheet;
@property (weak, nonatomic) IBOutlet UIView *screenContainerView;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (strong, nonatomic) UIWindow *airplayWindow;
@property (strong, nonatomic) GBAROMTableViewController *romTableViewController;
@property (strong, nonatomic) UIView *splashScreenView;
@property (strong, nonatomic) GBAEventDistributionViewController *eventDistributionViewController;
@property (copy, nonatomic) NSDictionary *eventDistributionROMs;

@property (copy, nonatomic) NSSet *buttonsToPressForNextCycle;
@property (strong, nonatomic) NSMutableSet *pressedButtons;

@property (assign, nonatomic) BOOL pausedEmulation;
@property (assign, nonatomic) BOOL stayPaused;
@property (assign, nonatomic) BOOL interfaceOrientationLocked;
@property (assign, nonatomic, getter = isLaunchingApplication) BOOL launchingApplication;

@property (assign, nonatomic, getter=isPlayingIntroAnimation) BOOL playingIntroAnimation;
@property (assign, nonatomic) BOOL shouldHideIntroAnimation;

@property (assign, nonatomic) BOOL usingGyroscope;
@property (assign, nonatomic) BOOL shouldResumeEmulationAfterRotatingInterface;
@property (assign, nonatomic, getter = isShowingGyroscopeAlert) BOOL showingGyroscopeAlert;

@property (assign, nonatomic) BOOL preventSavingROMSaveData;
@property (copy, nonatomic) NSData *cachedSaveData;

@property (readonly, assign, nonatomic, getter = isAirplaying) BOOL airplaying;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *portraitBottomLayoutConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *screenVerticalCenterLayoutConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *screenHorizontalCenterLayoutConstraint;

// Sustaining Buttons
@property (assign, nonatomic) BOOL selectingSustainedButton;
@property (strong, nonatomic) NSMutableSet *sustainedButtonSet;

// Fast Forward
@property (assign, nonatomic, getter = isFastForwarding) BOOL fastForwarding;

// Blurring
@property (assign, nonatomic) BOOL blurringContents;
@property (strong, nonatomic) UIImageView *sustainButtonBlurredContentsImageView;

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Emulation" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"emulationViewController"];
    if (self)
    {
        _launchingApplication = YES;
        
        _emulationViewController = self;
        
        [[GBAEmulatorCore sharedCore] setDelegate:self];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#if !(TARGET_IPHONE_SIMULATOR)
    self.emulatorScreen.backgroundColor = [UIColor blackColor]; // It's set to blue in the storyboard for easier visual debugging
#endif
    self.controllerView.delegate = self;
        
    if ([[UIScreen screens] count] > 1 && [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAirPlayEnabledKey])
    {
        UIScreen *newScreen = [UIScreen screens][1];
        [self setUpAirplayScreen:newScreen];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:GBASettingsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userRequestedToPlayROM:) name:GBAUserRequestedToPlayROMNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romDidSaveData:) name:GBAROMDidSaveDataNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hasNewDropboxSaveForCurrentGameFromDropbox:) name:GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldRestartCurrentGame:) name:GBAShouldRestartCurrentGameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncManagerFinishedSync:) name:GBASyncManagerFinishedSyncNotification object:[GBASyncManager sharedManager]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidConnect:) name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidConnect:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidDisconnect:) name:GCControllerDidDisconnectNotification object:nil];
    
    self.view.clipsToBounds = NO;
    
    // This isn't for FPS, remember? Keep it here stupid, it's for sustain button
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidUpdate:)];
	[self.displayLink setFrameInterval:1];
	[self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self updateFilter];
    
    [self updateSettings:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refreshLayout];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ([self isLaunchingApplication])
    {
        [self finishLaunchingApplication];
    }
    else
    {
        // Keep this here, used when we programmatically dismiss view controllers presented by custom transition view controllers (ex: add cheat on top of cheats menu)
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)finishLaunchingApplication
{
    DLog(@"App did launch");
    
    self.eventDistributionROMs = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"eventDistributionROMs" ofType:@"plist"]];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        // Add to our view so we can animate it
        [self.view addSubview:self.splashScreenView];
        
        self.romTableViewController = [[GBAROMTableViewController alloc] initWithNibName:nil bundle:nil];
        self.romTableViewController.appearanceDelegate = self;
        self.romTableViewController.view.layer.allowsGroupOpacity = YES;
        
        UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(self.romTableViewController);
        navigationController.modalPresentationStyle = UIModalPresentationCustom;
        navigationController.transitioningDelegate = self;
        
        [self presentViewController:navigationController animated:YES completion:^{
            
            //self.romTableViewController.view.layer.allowsGroupOpacity = NO;
            
            navigationController.transitioningDelegate = self;
            
            [self.splashScreenView removeFromSuperview];
            self.splashScreenView = nil;
            
            if (self.rom)
            {
                GBAROM *rom = self.rom;
                self.rom = nil;
                [self.romTableViewController startROM:rom];
            }
        }];
    }
    else
    {
        self.romTableViewController = [(GBASplitViewController *)self.splitViewController romTableViewController];
        [(GBASplitViewController *)self.splitViewController showROMTableViewControllerWithAnimation:NO];
        
        [UIView animateWithDuration:0.6 animations:^{
            self.splashScreenView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.splashScreenView removeFromSuperview];
            self.splashScreenView = nil;
            
            if (self.rom)
            {
                GBAROM *rom = self.rom;
                self.rom = nil;
                [self.romTableViewController startROM:rom];
            }
        }];
    }
    
    self.pressedButtons = [NSMutableSet set];
    
    [[[[UIApplication sharedApplication] delegate] window] bringSubviewToFront:self.splashScreenView];
    
    self.romTableViewController.emulationViewController = self;
    
    self.launchingApplication = NO;
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
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && self.rom == nil)
    {
        return YES;
    }
    
    return YES;
}

#pragma mark - Private

- (void)showSplashScreen
{
    CGRect bounds = [[UIScreen mainScreen] bounds];
    
    // iOS 7 doesn't support using Nibs for Launch Screens
    if (![[UIScreen mainScreen] respondsToSelector:@selector(fixedCoordinateSpace)])
    {
        UIImageView *imageView = [[UIImageView alloc] init];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            if ([[UIScreen mainScreen] isWidescreen])
            {
                imageView.image = [UIImage imageNamed:@"Default-568h"];
            }
            else
            {
                imageView.image = [UIImage imageNamed:@"Default"];
            }
        }
        else
        {
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            {
                imageView.image = [UIImage imageNamed:@"Default-Portrait"];
            }
            else
            {
                imageView.image = [UIImage imageNamed:@"Default-Landscape"];
            }
        }
        
        [imageView sizeToFit];
        imageView.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds)); // Make sure it is centered, so when it rotates it will line up
        
        CGAffineTransform transform = CGAffineTransformIdentity;
        
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        {
            if (self.interfaceOrientation == UIInterfaceOrientationPortrait)
            {
                transform = CGAffineTransformMakeRotation(RADIANS(0.0f));
            }
            else
            {
                transform = CGAffineTransformMakeRotation(RADIANS(180.0f));
            }
        }
        else
        {
            if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                transform = CGAffineTransformMakeRotation(RADIANS(270.0f));
            }
            else
            {
                transform = CGAffineTransformMakeRotation(RADIANS(90.0f));
            }
        }
        
        imageView.transform = transform;
        
        self.splashScreenView = imageView;
    }
    else
    {
        UINib *splashScreenViewNib = [UINib nibWithNibName:@"Launch Screen" bundle:nil];
        NSArray *views = [splashScreenViewNib instantiateWithOwner:nil options:nil];
        
        self.splashScreenView = [views firstObject];
        self.splashScreenView.frame = CGRectMake(0, 0, CGRectGetWidth(bounds), CGRectGetHeight(bounds));
        
        self.splashScreenView.layer.allowsGroupOpacity = YES;
    }
    
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    [window addSubview:self.splashScreenView];
}

- (CGSize)screenSizeForContainerSize:(CGSize)containerSize
{
    CGSize resolution = CGSizeZero;
    
    switch (self.rom.type)
    {
        case GBAROMTypeGBA:
            resolution = CGSizeMake(240, 160);
            break;
            
        case GBAROMTypeGBC:
            resolution = CGSizeMake(160, 144);
            break;
    }
    
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
    
    return CGSizeMake(roundf(size.width), roundf(size.height));
}

- (NSString *)filepathForSkinIdentifier:(NSString *)identifier
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *skinsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Skins"];
    
    NSString *filepath = [skinsDirectory stringByAppendingPathComponent:identifier];
    
    return filepath;
}

- (void)userRequestedToPlayROM:(NSNotification *)notification
{
    [self.pausedActionSheet dismissWithClickedButtonIndex:0 animated:YES];
    self.pausedActionSheet = nil;
    
    if (self.selectingSustainedButton)
    {
        [self exitSustainButtonSelectionMode];
        [self pauseEmulation];
    }
}

- (void)displayLinkDidUpdate:(CADisplayLink *)displayLink
{
    [self updateControllerInputs];
    
    if (self.shouldHideIntroAnimation)
    {
        _hideIntroAnimationFrameCount++;
        
        if (_hideIntroAnimationFrameCount > 1)
        {
            self.shouldHideIntroAnimation = NO;
            self.emulatorScreen.introAnimationLayer = nil;
            
            _hideIntroAnimationFrameCount = 0;
        }
    }
}

#pragma mark - Intro Animation

- (void)playIntroAnimation
{
    self.playingIntroAnimation = YES;
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"Intro" withExtension:@"mp4"]];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.backgroundColor = [UIColor blackColor].CGColor;
    self.emulatorScreen.introAnimationLayer = playerLayer;
    
    __block id observer = nil;
    observer = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:playerItem queue:nil usingBlock:^(NSNotification *notification) {
        
        self.playingIntroAnimation = NO;
        
        [self resumeEmulation];
        
        // Delay until screen refresh so previous game is never seen
        self.shouldHideIntroAnimation = YES;
        _hideIntroAnimationFrameCount = 0;
        
        [[NSNotificationCenter defaultCenter] removeObserver:observer name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
        
    }];
    
    [player play];
}

#pragma mark - Airplay

- (void)screenDidConnect:(NSNotification *)notification
{
    if ([self isAirplaying] || ![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAirPlayEnabledKey])
    {
        return;
    }
    
    UIScreen *newScreen = [notification object];
    [self setUpAirplayScreen:newScreen];
}

- (void)screenDidDisconnect:(NSNotification *)notification
{
    if (![self isAirplaying])
    {
        return;
    }
    
    [self tearDownAirplayScreen];
}

- (void)setUpAirplayScreen:(UIScreen *)screen
{
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenBounds = screen.bounds;
        
        self.airplayWindow = ({
            UIWindow *window = [[UIWindow alloc] initWithFrame:screenBounds];
            window.screen = screen;
            window.hidden = NO;
                        
            [window addSubview:self.emulatorScreen];
            
            window;
        });
        
        NSLayoutConstraint *horizontalCenterConstraint = [NSLayoutConstraint constraintWithItem:self.emulatorScreen
                                                                                      attribute:NSLayoutAttributeCenterX
                                                                                      relatedBy:NSLayoutRelationEqual
                                                                                         toItem:self.airplayWindow
                                                                                      attribute:NSLayoutAttributeCenterX
                                                                                     multiplier:1.0f
                                                                                       constant:0.0f];
        
        NSLayoutConstraint *landscapeCenterConstraint = [NSLayoutConstraint constraintWithItem:self.emulatorScreen
                                                                                     attribute:NSLayoutAttributeCenterY
                                                                                     relatedBy:NSLayoutRelationEqual
                                                                                        toItem:self.airplayWindow
                                                                                     attribute:NSLayoutAttributeCenterY
                                                                                    multiplier:1.0f
                                                                                      constant:0.0f];
        
        [self.airplayWindow addConstraints:@[horizontalCenterConstraint, landscapeCenterConstraint]];
        
        [self.emulatorScreen invalidateIntrinsicContentSize];
        
        [self refreshLayout];
    });
}

- (void)tearDownAirplayScreen
{
    self.airplayWindow.hidden = YES;
    
    [self.screenContainerView addSubview:self.emulatorScreen];
    self.airplayWindow = nil;
    
    [self refreshLayout];
}

#pragma mark - Controller

- (void)controllerDidConnect:(NSNotification *)notification
{
    if (self.externalController)
    {
        return;
    }
    
    GCController *controller = notification.object;
    [controller setPlayerIndex:GCControllerPlayerIndex1];
    
    self.externalController = [GBAExternalController externalControllerWithController:controller];
    self.externalController.delegate = self;
    
    if (self.selectingSustainedButton)
    {
        return;
    }
    
    // Can lead to incorrect layout if there isn't a ROM loaded
    if (self.rom)
    {
        [self refreshLayout];
    }
}

- (void)controllerDidDisconnect:(NSNotification *)notification
{
    if (self.externalController.controller != notification.object)
    {
        return;
    }
    
    self.externalController = nil;
    
    if (self.selectingSustainedButton)
    {
        return;
    }
    
    // Can lead to incorrect layout if there isn't a ROM loaded
    if (self.rom)
    {
        [self refreshLayout];
    }
}

- (void)controllerInput:(id)controllerInput didPressButtons:(NSSet *)buttons
{
    if (self.presentedViewController || ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && [(GBASplitViewController *)self.splitViewController romTableViewControllerIsVisible]))
    {
        return;
    }
    
    // Sustain Button
    if ([buttons containsObject:@(GBAControllerButtonSustainButton)])
    {
        [self pauseEmulation];
        
        if (self.selectingSustainedButton)
        {
            [self sustainButtons:nil];
        }
        else
        {
            [self enterSustainButtonSelectionMode];
        }
        
        return;
    }
    
    // Allow sustaining fast forward button
    if (self.selectingSustainedButton)
    {
        [self sustainButtons:buttons];
    }
    
    [self.pressedButtons unionSet:buttons];
    
    if (self.rom.type == GBAROMTypeGBC && [self isPlayingIntroAnimation])
    {
        [self updateColorPaletteForPressedButtons:self.pressedButtons];
    }
    
    if ([buttons containsObject:@(GBAControllerButtonFastForward)])
    {
        // Stop fast forwarding on when finished pressing button
        [self startFastForwarding];
        
        return;
    }
    
    // If selecting sustain button, nothing else in this method is relevant
    if (self.selectingSustainedButton)
    {
        return;
    }
    
    
    if ([self.sustainedButtonSet intersectsSet:buttons]) // We re-pressed a sustained button, so we need to release it then press it in the next emulation CPU cycle
    {
        if ([buttons count] == 0)
        {
            return;
        }
        
        NSMutableSet *sustainedButtons = [self.sustainedButtonSet mutableCopy];
        [sustainedButtons intersectSet:buttons];
        
        [[GBAEmulatorCore sharedCore] releaseButtons:sustainedButtons];
        
        NSMutableSet *buttonsWithoutSustainButtons = [buttons mutableCopy];
        [buttonsWithoutSustainButtons minusSet:self.sustainedButtonSet];
        
        self.buttonsToPressForNextCycle = buttons;
        
        _sustainButtonFrameCount = 0;
    }
    else
    {
        if ([buttons count] == 0)
        {
            return;
        }
        
        [[GBAEmulatorCore sharedCore] pressButtons:buttons];
    }
}

- (void)controllerInput:(id)controllerInput didReleaseButtons:(NSSet *)buttons
{
    // Sustain Button
    if ([buttons containsObject:@(GBAControllerButtonSustainButton)])
    {
        // Do nothing
        return;
    }
    
    [self.pressedButtons minusSet:buttons];
    
    if (self.rom.type == GBAROMTypeGBC && [self isPlayingIntroAnimation])
    {
        [self updateColorPaletteForPressedButtons:self.pressedButtons];
    }
    
    if ([buttons containsObject:@(GBAControllerButtonFastForward)])
    {
        if (![self.sustainedButtonSet containsObject:@(GBAControllerButtonFastForward)])
        {
            [self stopFastForwarding];
        }
        
        return;
    }
    
    if (self.sustainedButtonSet)
    {
        NSMutableSet *set = [buttons mutableCopy];
        [set minusSet:self.sustainedButtonSet];
        buttons = set;
    }
    
    
    [[GBAEmulatorCore sharedCore] releaseButtons:buttons];
}

- (void)updateControllerInputs
{
    if (self.buttonsToPressForNextCycle)
    {
        _sustainButtonFrameCount++;
        
        if (_sustainButtonFrameCount > 1)
        {
            _sustainButtonFrameCount = 0;
            
            [[GBAEmulatorCore sharedCore] pressButtons:self.buttonsToPressForNextCycle];
            
            self.buttonsToPressForNextCycle = nil;
        }
    }
    
#ifdef USE_POLLING
    if (self.externalController == nil)
    {
        return;
    }
    
    [self.externalController updateControllerInputs];
    
#endif
}

- (void)updateColorPaletteForPressedButtons:(NSSet *)pressedButtons
{
    GBCColorPalette overrideColorPalette = (GBCColorPalette)[[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsSelectedColorPaletteKey];
    
    if ([pressedButtons isEqualToSet:[NSSet setWithObject:@(GBAControllerButtonUp)]])
    {
        overrideColorPalette = GBCColorPaletteBrown;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObject:@(GBAControllerButtonLeft)]])
    {
        overrideColorPalette = GBCColorPaletteBlue;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObject:@(GBAControllerButtonDown)]])
    {
        overrideColorPalette = GBCColorPalettePastelMix;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObject:@(GBAControllerButtonRight)]])
    {
        overrideColorPalette = GBCColorPaletteGreen;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonUp), @(GBAControllerButtonA), nil]])
    {
        overrideColorPalette = GBCColorPaletteRed;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonLeft), @(GBAControllerButtonA), nil]])
    {
        overrideColorPalette = GBCColorPaletteDarkBlue;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonDown), @(GBAControllerButtonA), nil]])
    {
        overrideColorPalette = GBCColorPaletteOrange;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonRight), @(GBAControllerButtonA), nil]])
    {
        overrideColorPalette = GBCColorPaletteDarkGreen;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonUp), @(GBAControllerButtonB), nil]])
    {
        overrideColorPalette = GBCColorPaletteDarkBrown;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonLeft), @(GBAControllerButtonB), nil]])
    {
        overrideColorPalette = GBCColorPaletteGray;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonDown), @(GBAControllerButtonB), nil]])
    {
        overrideColorPalette = GBCColorPaletteYellow;
    }
    else if ([pressedButtons isEqualToSet:[NSSet setWithObjects:@(GBAControllerButtonRight), @(GBAControllerButtonB), nil]])
    {
        overrideColorPalette = GBCColorPaletteReverse;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsSelectedColorPaletteKey, @"value": @(overrideColorPalette)}];
}

#pragma mark - Pause Menu

- (void)controllerInputDidPressMenuButton:(id)controllerInput
{
    if (self.presentedViewController)
    {
        return;
    }
    
    if (self.pausedActionSheet)
    {
        [self.pausedActionSheet dismissWithClickedButtonIndex:0 animated:YES];
        [self resumeEmulation];
        self.pausedActionSheet = nil;
        
        return;
    }
    
    if (self.selectingSustainedButton)
    {
        [self sustainButtons:nil];
        return;
    }
    
    _romPauseTime = CFAbsoluteTimeGetCurrent();

    if (![[GBALinkManager sharedManager] isLinkConnected])
    {
        [self pauseEmulation];
    }
    
    
    if ([self usingGyroscope] && ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad || [UIAlertController class]))
    {
        [UIViewController attemptRotationToDeviceOrientation];
    }
    
    NSString *pauseMenuTitle = nil;
    
    if ([[GBALinkManager sharedManager] isLinkConnected])
    {
        pauseMenuTitle = NSLocalizedString(@"When Wireless Link is connected, the game cannot be paused.", @"");
    }
    else
    {
        pauseMenuTitle = NSLocalizedString(@"Paused", @"");
    }
    
    
    NSString *returnToMenuButtonTitle = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        returnToMenuButtonTitle = NSLocalizedString(@"Show Game List", @"");
    }
    else
    {
        returnToMenuButtonTitle = NSLocalizedString(@"Return To Menu", @"");
    }
    
    
    NSString *fastForwardButtonTitle = nil;
    
    if (self.fastForwarding)
    {
        fastForwardButtonTitle = NSLocalizedString(@"Normal Speed", @"");
    }
    else
    {
        fastForwardButtonTitle = NSLocalizedString(@"Fast Forward", @"");
    }
    
    BOOL eventDistributionCapableROM = ([self.eventDistributionROMs objectForKey:self.rom.uniqueName] != nil);
    
    // iOS 7 has trouble adding buttons to UIActionSheet after it's created, so we just create a different action sheet depending on hardware and situation
    if ([self.rom event])
    {
        if ([self numberOfCPUCoresForCurrentDevice] == 1)
        {
            self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                 delegate:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle:NSLocalizedString(@"Exit Event Distribution", @"")
                                                        otherButtonTitles:
                                      NSLocalizedString(@"Sustain Button", @""), nil];
        }
        else
        {
            self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                 delegate:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle:NSLocalizedString(@"Exit Event Distribution", @"")
                                                        otherButtonTitles:
                                      fastForwardButtonTitle,
                                      NSLocalizedString(@"Sustain Button", @""), nil];
        }
    }
    else
    {
        if ([[GBALinkManager sharedManager] isLinkConnected])
        {
            self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                 delegate:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle:returnToMenuButtonTitle
                                                        otherButtonTitles:
                                      NSLocalizedString(@"Sustain Button", @""), nil];
        }
        else if (eventDistributionCapableROM)
        {
            if ([self numberOfCPUCoresForCurrentDevice] == 1)
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                       destructiveButtonTitle:returnToMenuButtonTitle
                                                            otherButtonTitles:
                                          NSLocalizedString(@"Save State", @""),
                                          NSLocalizedString(@"Load State", @""),
                                          NSLocalizedString(@"Cheat Codes", @""),
                                          NSLocalizedString(@"Sustain Button", @""),
                                          NSLocalizedString(@"Event Distribution", @""), nil];
            }
            else
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                       destructiveButtonTitle:returnToMenuButtonTitle
                                                            otherButtonTitles:
                                          fastForwardButtonTitle,
                                          NSLocalizedString(@"Save State", @""),
                                          NSLocalizedString(@"Load State", @""),
                                          NSLocalizedString(@"Cheat Codes", @""),
                                          NSLocalizedString(@"Sustain Button", @""),
                                          NSLocalizedString(@"Event Distribution", @""), nil];
            }
        }
        else if (self.usingGyroscope && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && ![UIAlertController class])
        {
            // Only show on iOS 7 iPhones. iPads and iOS 8 iPhones don't need Rotate To Device Orientation Button
            
            if ([self numberOfCPUCoresForCurrentDevice] == 1)
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                       destructiveButtonTitle:returnToMenuButtonTitle
                                                            otherButtonTitles:
                                          NSLocalizedString(@"Save State", @""),
                                          NSLocalizedString(@"Load State", @""),
                                          NSLocalizedString(@"Cheat Codes", @""),
                                          NSLocalizedString(@"Sustain Button", @""),
                                          NSLocalizedString(@"Rotate To Device Orientation", @""), nil];
            }
            else
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                       destructiveButtonTitle:returnToMenuButtonTitle
                                                            otherButtonTitles:
                                          fastForwardButtonTitle,
                                          NSLocalizedString(@"Save State", @""),
                                          NSLocalizedString(@"Load State", @""),
                                          NSLocalizedString(@"Cheat Codes", @""),
                                          NSLocalizedString(@"Sustain Button", @""),
                                          NSLocalizedString(@"Rotate To Device Orientation", @""), nil];
            }
        }
        else
        {
            if ([self numberOfCPUCoresForCurrentDevice] == 1)
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                       destructiveButtonTitle:returnToMenuButtonTitle
                                                            otherButtonTitles:
                                          NSLocalizedString(@"Save State", @""),
                                          NSLocalizedString(@"Load State", @""),
                                          NSLocalizedString(@"Cheat Codes", @""),
                                          NSLocalizedString(@"Sustain Button", @""), nil];
            }
            else
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:pauseMenuTitle
                                                                     delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                       destructiveButtonTitle:returnToMenuButtonTitle
                                                            otherButtonTitles:
                                          fastForwardButtonTitle,
                                          NSLocalizedString(@"Save State", @""),
                                          NSLocalizedString(@"Load State", @""),
                                          NSLocalizedString(@"Cheat Codes", @""),
                                          NSLocalizedString(@"Sustain Button", @""), nil];
            }
        }
        
    }
    
    __block BOOL alreadyHandledActionSheetCallback = NO; // Eww eww eww hack because iOS 8 calls UIActionSheet delegate method twice
    
    void (^selectionHandler)(UIActionSheet *actionSheet, NSInteger buttonIndex) = ^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
        
        if (alreadyHandledActionSheetCallback)
        {
            return;
        }
        
        alreadyHandledActionSheetCallback = YES;
        
        if (buttonIndex == 0)
        {
            if ([self.rom event])
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Exit this event?", @"")
                                                                message:NSLocalizedString(@"The game will restart, and any unsaved data will be lost. If you haven't yet completed the event, you may start it again at any time.", @"")
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                      otherButtonTitles:NSLocalizedString(@"Exit", @""), nil];
                [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                    if (buttonIndex == 1)
                    {
                        [self finishEventDistribution];
                    }
                    else
                    {
                        [self resumeEmulation];
                    }
                }];
            }
            else if ([[GBALinkManager sharedManager] isLinkConnected])
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Suspend this game?", @"")
                                                                message:NSLocalizedString(@"The game will be suspended, which may cause link errors for connected players.", @"")
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                      otherButtonTitles:NSLocalizedString(@"Suspend", @""), nil];
                [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                    if (buttonIndex == 1)
                    {
                        [self pauseEmulation];
                        
                        [[GBASyncManager sharedManager] setShouldShowSyncingStatus:YES];
                        [self returnToROMTableViewController];
                    }
                    else
                    {
                        [self resumeEmulation];
                    }
                }];
            }
            else
            {
                [[GBASyncManager sharedManager] setShouldShowSyncingStatus:YES];
                
                [self returnToROMTableViewController];
            }
        }
        else {
            
            if ([[GBALinkManager sharedManager] isLinkConnected] && ![self.rom event])
            {
                // Compensate for lack of Fast Forward, Save State, Load State, and Cheat Codes buttons
                buttonIndex = buttonIndex + 4;
            }
            else
            {
                // Even if link is connected, Event Distribution menu has priority. Otherwise this is just for non-link connected menus
                
                if ([self numberOfCPUCoresForCurrentDevice] == 1)
                {
                    // Compensate for lack of Fast Forward button
                    buttonIndex = buttonIndex + 1;
                }
                
                if ([self.rom event] && buttonIndex > 1)
                {
                    // We hide Save State, Load State, and Cheat Codes
                    buttonIndex = buttonIndex + 3;
                }
            }
            
            
            if (buttonIndex == 1)
            {
                if ([self isFastForwarding])
                {
                    [self stopFastForwarding];
                }
                else
                {
                    [self startFastForwarding];
                }
                
                [self resumeEmulation];
            }
            else if (buttonIndex == 2)
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
            else if (buttonIndex == 6)
            {
                if ([[GBALinkManager sharedManager] isLinkConnected])
                {
                    [self resumeEmulation];
                }
                else if (eventDistributionCapableROM)
                {
                    if (![self.rom event])
                    {
                        [self presentEventDistribution];
                    }
                    else
                    {
                        [self resumeEmulation];
                    }
                }
                else if (self.usingGyroscope && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && ![UIAlertController class])
                {
                    // Only needed on iOS 7 iPhones. iPads and iOS 8 iPhones don't need Rotate To Device Orientation Button
                    
                    self.shouldResumeEmulationAfterRotatingInterface = YES;
                    [UIViewController attemptRotationToDeviceOrientation];
                }
                else
                {
                    [self resumeEmulation];
                }
            }
            else
            {                
                [self resumeEmulation];
            }
        }
        
        self.pausedActionSheet = nil;
    };
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [self.pausedActionSheet showInView:self.view selectionHandler:selectionHandler];
        
        return;
    }
    
    if ([self isExternalControllerConnected])
    {
        [self.pausedActionSheet showInView:self.view selectionHandler:selectionHandler];
        
        return;
    }
    
    // Below code used in didRotateFromInterfaceOrientation as well, except without the selectionHandler
    
    CGRect rect = [self.controllerView.controllerSkin frameForMapping:GBAControllerSkinMappingMenu orientation:self.controllerView.orientation controllerDisplaySize:self.view.window.bounds.size useExtendedEdges:NO];
    
    CGRect convertedRect = [self.view convertRect:rect fromView:self.controllerView];
    
    CGFloat middleSectionStart = CGRectGetWidth(self.view.bounds) * (1.0/3.0);
    CGFloat middleSectionEnd = CGRectGetWidth(self.view.bounds) * (2.0/3.0);
    
    // Button is in the middle third of the screen, so we make sure it centers the popup instead of putting it off to the side like normal
    if (CGRectGetMidX(convertedRect) > middleSectionStart && CGRectGetMidX(convertedRect) < middleSectionEnd)
    {
        convertedRect.origin.x = 0;
        convertedRect.size.width = self.controllerView.bounds.size.width;
    }
    
    [self.pausedActionSheet showFromRect:convertedRect inView:self.view animated:YES selectionHandler:selectionHandler];
}

- (unsigned int)numberOfCPUCoresForCurrentDevice
{
    size_t len;
    unsigned int ncpu;
    
    len = sizeof(ncpu);
    sysctlbyname ("hw.ncpu",&ncpu,&len,NULL,0);
    
    return ncpu;
}

#pragma mark - Sustain Button

- (void)enterSustainButtonSelectionMode
{
    self.selectingSustainedButton = YES;
    self.interfaceOrientationLocked = YES;
    
    if (self.emulatorScreen.eaglView == nil)
    {
        return;
    }
    
    self.sustainButtonBlurredContentsImageView = ({
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds))];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        imageView.alpha = 0.0;
        
        UIImage *image = [self blurredViewImageForInterfaceOrientation:self.interfaceOrientation drawController:NO];
        imageView.image = image;
        
        [self.view insertSubview:imageView belowSubview:self.controllerView];
        
        imageView;
    });
    
    BOOL screenRectEmpty = NO;
    CGRect screenRect = [self.controllerView.controllerSkin frameForMapping:GBAControllerSkinMappingScreen orientation:self.controllerView.orientation controllerDisplaySize:self.view.window.bounds.size];
    
    if (CGRectIsEmpty(screenRect))
    {
        screenRectEmpty = YES;
        screenRect = self.screenContainerView.frame;
    }
    
    UILabel *instructionsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(screenRect) - 20.0f, CGRectGetHeight(screenRect) - 20.0f)];
    instructionsLabel.minimumScaleFactor = 0.5;
    instructionsLabel.numberOfLines = 0.0;
    instructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    instructionsLabel.textAlignment = NSTextAlignmentCenter;
    
    if (self.externalController)
    {
        instructionsLabel.text = NSLocalizedString(@"Press the button you want to sustain.\n\nTo cancel or unsustain a previously sustained button, either tap the screen or press the Menu button.", @"");
    }
    else
    {
        instructionsLabel.text = NSLocalizedString(@"Tap the button you want to sustain.\n\nTo cancel or unsustain a previously sustained button, tap anywhere there isn't a button.", @"");
    }
    
    instructionsLabel.textColor = [UIColor whiteColor];
    
    instructionsLabel.center = CGPointMake(CGRectGetMidX(screenRect), CGRectGetMidY(screenRect));
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && self.controllerView.orientation == GBAControllerSkinOrientationLandscape)
    {
        if (screenRectEmpty && self.externalController == nil) // With external controller, we want it to be centered
        {
            instructionsLabel.center = ({
                CGPoint center = instructionsLabel.center;
                center.y -= 40.0f;
                center;
            });
        }
    }
    
    [self.sustainButtonBlurredContentsImageView addSubview:instructionsLabel];
    
    [UIView animateWithDuration:0.3 animations:^{
        [self.sustainButtonBlurredContentsImageView setAlpha:1.0f];
    }];
    
}

- (void)exitSustainButtonSelectionMode
{
    [UIView animateWithDuration:0.3 animations:^{
        [self.sustainButtonBlurredContentsImageView setAlpha:0.0f];
    } completion:^(BOOL finished) {
        self.interfaceOrientationLocked = NO;
        [self.sustainButtonBlurredContentsImageView removeFromSuperview];
        self.sustainButtonBlurredContentsImageView = nil;
        
        [UIViewController attemptRotationToDeviceOrientation];
    }];
    
    self.selectingSustainedButton = NO;
    
    [self updateControllerSkinForInterfaceOrientation:self.interfaceOrientation];
    [self updateEmulatorScreenFrame]; // In case user connected/disconnected external controller
    
    [self resumeEmulation];
}

- (void)sustainButtons:(NSSet *)buttons
{
    // Release previous sustained buttons
    [[GBAEmulatorCore sharedCore] releaseButtons:self.sustainedButtonSet];
    
    if ([self.sustainedButtonSet containsObject:@(GBAControllerButtonFastForward)])
    {
        [self stopFastForwarding];
    }
    
    self.sustainedButtonSet = [buttons mutableCopy];
    [self exitSustainButtonSelectionMode];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.selectingSustainedButton)
    {
        [self sustainButtons:nil];
    }
}

#pragma mark - Fast Forward

- (void)startFastForwarding
{
    self.fastForwarding = YES;
    
    [[GBAEmulatorCore sharedCore] startFastForwarding];
}

- (void)stopFastForwarding
{
    self.fastForwarding = NO;
    
    [[GBAEmulatorCore sharedCore] stopFastForwarding];
}

#pragma mark - Save States

- (void)presentSaveStateMenuWithMode:(GBASaveStateViewControllerMode)mode
{
    GBASaveStateViewController *saveStateViewController = [[GBASaveStateViewController alloc] initWithROM:self.rom mode:mode];
    saveStateViewController.delegate = self;
    
    GBAKeyboardDismissalNavigationController *navigationController = [[GBAKeyboardDismissalNavigationController alloc] initWithRootViewController:saveStateViewController];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        saveStateViewController.theme = GBAThemedTableViewControllerThemeTranslucent;
        navigationController.modalPresentationStyle = UIModalPresentationCustom;
        navigationController.transitioningDelegate = self;
    }
    else
    {
        saveStateViewController.theme = GBAThemedTableViewControllerThemeOpaque;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    if ([UIAlertController class] && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) // iOS 8 beta 3 glitch: can't present while UIActionController is dismissing
    {
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentViewController:navigationController animated:YES completion:nil];
            [self prepareForPresentingTranslucentViewController];
        }];
    }
    else
    {
        [self presentViewController:navigationController animated:YES completion:nil];
        [self prepareForPresentingTranslucentViewController];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController willLoadStateWithFilename:(NSString *)filename
{
    if ([filename hasPrefix:@"autosave"] && [self shouldAutosave])
    {
        NSString *backupFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"backup.sgm"];
        [[GBAEmulatorCore sharedCore] saveStateToFilepath:backupFilepath];
    }
    else
    {
        if ([self shouldAutosave])
        {
            [self updateAutosaveState];
        }
    }
}

- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController didLoadStateWithFilename:(NSString *)filename
{
    if ([filename hasPrefix:@"autosave"] && [self shouldAutosave])
    {
        NSString *autosaveFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"autosave.sgm"];
        NSString *backupFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"backup.sgm"];
        
        [[NSFileManager defaultManager] replaceItemAtURL:[NSURL fileURLWithPath:autosaveFilepath] withItemAtURL:[NSURL fileURLWithPath:backupFilepath] backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:nil error:nil];
    }
    
    [[GBAEmulatorCore sharedCore] updateCheats];
}

- (void)saveStateViewControllerWillDismiss:(GBASaveStateViewController *)saveStateViewController
{
    [self resumeEmulation];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [UIView animateWithDuration:0.4 animations:^{
            [self setBlurAlpha:0.0];
        } completion:^(BOOL finished) {
            [self removeBlur];
        }];
    }
}

- (void)autoSaveIfPossible
{
    if (self.rom && [self shouldAutosave])
    {
        [self updateAutosaveState];
    }
}

- (BOOL)shouldAutosave
{
    // If the user loads a save state in the first 3 seconds, the autosave would probably be useless to them as it would take them back to the title screen of their game
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"autosave"] && (_romPauseTime - _romStartTime >= 3.0f) && ![self.rom event];
}

- (void)updateAutosaveState
{
    NSString *autosaveFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"autosave.sgm"];
    [[GBAEmulatorCore sharedCore] saveStateToFilepath:autosaveFilepath];
}

- (NSString *)saveStateDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *saveStateParentDirectory = [documentsDirectory stringByAppendingPathComponent:@"Save States"];
    NSString *saveStateDirectory = [saveStateParentDirectory stringByAppendingPathComponent:self.rom.name];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:saveStateDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return saveStateDirectory;
}

#pragma mark - Cheats

- (void)presentCheatManager
{
    GBACheatManagerViewController *cheatManagerViewController = [[GBACheatManagerViewController alloc] initWithROM:self.rom];
    cheatManagerViewController.delegate = self;
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(cheatManagerViewController);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        cheatManagerViewController.theme = GBAThemedTableViewControllerThemeTranslucent;
        navigationController.modalPresentationStyle = UIModalPresentationCustom;
        navigationController.transitioningDelegate = self;
    }
    else
    {
        cheatManagerViewController.theme = GBAThemedTableViewControllerThemeOpaque;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    if ([UIAlertController class] && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) // iOS 8 beta 3 glitch: can't present while UIActionController is dismissing
    {
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentViewController:navigationController animated:YES completion:nil];
            [self prepareForPresentingTranslucentViewController];
        }];
    }
    else
    {
        [self presentViewController:navigationController animated:YES completion:nil];
        [self prepareForPresentingTranslucentViewController];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController willDismissCheatEditorViewController:(GBACheatEditorViewController *)cheatEditorViewController
{
    [self refreshLayout];
}

- (void)cheatManagerViewControllerWillDismiss:(GBACheatManagerViewController *)cheatManagerViewController
{
    [self resumeEmulation];
    
    [self prepareForDismissingTranslucentViewController];
}

#pragma mark - Event Distribution

- (void)presentEventDistribution
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
    
    GBAEventDistributionViewController *eventDistributionViewController = [[GBAEventDistributionViewController alloc] initWithROM:self.rom];
    eventDistributionViewController.delegate = self;
    eventDistributionViewController.emulationViewController = self;
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(eventDistributionViewController);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    if ([UIAlertController class] && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) // iOS 8 beta 3 glitch: can't present while UIActionController is dismissing
    {
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentViewController:navigationController animated:YES completion:nil];
            [self prepareForPresentingTranslucentViewController];
        }];
    }
    else
    {
        [self presentViewController:navigationController animated:YES completion:nil];
        [self prepareForPresentingTranslucentViewController];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)finishEventDistribution
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(self.eventDistributionViewController);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [self presentViewController:navigationController animated:YES completion:nil];
    
    [self prepareForPresentingTranslucentViewController];
    
    [self.eventDistributionViewController finishCurrentEvent];
}

- (void)eventDistributionViewController:(GBAEventDistributionViewController *)eventDistributionViewController willStartEvent:(GBAROM *)eventROM
{
    self.eventDistributionViewController = eventDistributionViewController;
}

- (void)eventDistributionViewController:(GBAEventDistributionViewController *)eventDistributionViewController didFinishEvent:(GBAROM *)eventROM
{
    self.eventDistributionViewController = nil;
}

- (void)eventDistributionViewControllerWillDismiss:(GBAEventDistributionViewController *)eventDistributionViewController
{
    [self refreshLayout];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    
    [self resumeEmulation];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [UIView animateWithDuration:0.4 animations:^{
            [self setBlurAlpha:0.0];
        } completion:^(BOOL finished) {
            [self removeBlur];
        }];
    }
}

#pragma mark - GBAEmulatorCoreDelegate

- (void)emulatorCore:(GBAEmulatorCore *)emulatorCore didEnableGyroscopeForROM:(GBAROM *)rom
{
    self.usingGyroscope = YES;
    
    NSString *key = nil;
    
    if ([UIAlertController class])
    {
        // On iOS 8, both iPad and iPhone can automatically rotate to a new orientation when paused, so no need to differentiate
        key = @"presentedGyroscopeAlert";
    }
    else
    {
        // We differentiate because they are different messages, and if the user backs up and restores from one device to another type, they should see the other message.
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            key = @"presentediPhoneGyroscopeAlert";
        }
        else
        {
            key = @"presentediPadGyroscopeAlert";
        }
    }
    
    NSInteger alertPresentationCount = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    
    if (alertPresentationCount < 3)
    {
        self.showingGyroscopeAlert = YES;
        
        [self pauseEmulation];
        
        NSString *message = nil;
        
        // On iOS 8+, or iPads, you don't have to manually tap "Rotate To Device Orientation". On iOS 7 iPhones, you do
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad || [UIAlertController class])
        {
            message = NSLocalizedString(@"To prevent GBA4iOS from rotating between portrait and landscape accidentally, automatic rotation has been disabled. To manually rotate the interface, pause the game, then rotate the device.", @"");
        }
        else
        {
            message = NSLocalizedString(@"To prevent GBA4iOS from rotating between portrait and landscape accidentally, automatic rotation has been disabled. To manually rotate to the device orientation, pause the game, then tap “Rotate To Device Orientation”.", @"");
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.emulatorScreen.hidden = YES; // Hide it in case a previous ROM is loaded, since it will pause on the last game screen
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Game Uses Gyroscope", @"")
                                                            message:message
                                                           delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
            [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                self.showingGyroscopeAlert = NO;
                [self resumeEmulation];
                
                self.emulatorScreen.hidden = NO;
            }];
        });
        
        alertPresentationCount++;
        [[NSUserDefaults standardUserDefaults] setInteger:alertPresentationCount forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - Settings

- (void)updateSettings:(NSNotification *)notification
{    
    BOOL translucent = [self.controllerView.controllerSkin isTranslucentForOrientation:self.controllerView.orientation];
    
    if (translucent)
    {
        self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
    }
    else
    {
        self.controllerView.skinOpacity = 1.0f;
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsAirPlayEnabledKey])
    {
        if (![self isAirplaying] && [[UIScreen screens] count] > 1)
        {
            [self setUpAirplayScreen:[UIScreen screens][1]];
        }
    }
    else
    {
        if ([self isAirplaying])
        {
            [self tearDownAirplayScreen];
        }
    }
}

#pragma mark - Presenting/Dismissing


- (void)returnToROMTableViewController
{
    if ([self shouldAutosave])
    {
        [self updateAutosaveState];
    }
    
    // Saves when pausing the game
    
    [[GBASyncManager sharedManager] synchronize];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(self.romTableViewController);
        self.romTableViewController.theme = GBAThemedTableViewControllerThemeTranslucent;
        navigationController.transitioningDelegate = self;
        navigationController.modalPresentationStyle = UIModalPresentationCustom;
        [self presentViewController:navigationController animated:YES completion:NULL];
    }
    else
    {
        [(GBASplitViewController *)self.splitViewController showROMTableViewControllerWithAnimation:YES];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                  presentingController:(UIViewController *)presenting
                                                                      sourceController:(UIViewController *)source {
    
    UIViewController *viewController = presented;
    
    if ([viewController isKindOfClass:[UINavigationController class]])
    {
        viewController = [[(UINavigationController *)viewController viewControllers] firstObject];
    }
    
    if ([viewController isKindOfClass:[GBAROMTableViewController class]])
    {
        if ([(GBAROMTableViewController *)viewController theme] == GBAThemedTableViewControllerThemeOpaque)
        {
            GBAInitialPresentROMTableViewControllerAnimator *animator = [[GBAInitialPresentROMTableViewControllerAnimator alloc] init];
            animator.presenting = YES;
            return animator;
        }
        else
        {
            GBAROMTableViewControllerAnimator *animator = [[GBAROMTableViewControllerAnimator alloc] init];
            animator.presenting = YES;
            return animator;
        }
    }
    else if ([viewController isKindOfClass:[GBASaveStateViewController class]] || [viewController isKindOfClass:[GBACheatManagerViewController class]])
    {
        GBAPresentOverlayViewControllerAnimator *animator = [[GBAPresentOverlayViewControllerAnimator alloc] init];
        animator.presenting = YES;
        return animator;
    }
    
    return nil;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    
    UIViewController *viewController = dismissed;
    
    if ([viewController isKindOfClass:[UINavigationController class]])
    {
        viewController = [[(UINavigationController *)viewController viewControllers] firstObject];
    }
    
    if ([viewController isKindOfClass:[GBAROMTableViewController class]])
    {
        if ([(GBAROMTableViewController *)viewController theme] == GBAThemedTableViewControllerThemeOpaque)
        {
            GBAInitialPresentROMTableViewControllerAnimator *animator = [[GBAInitialPresentROMTableViewControllerAnimator alloc] init];
            animator.presenting = NO;
            return animator;
        }
        else
        {
            GBAROMTableViewControllerAnimator *animator = [[GBAROMTableViewControllerAnimator alloc] init];
            return animator;
        }
    }
    else if ([viewController isKindOfClass:[GBASaveStateViewController class]] || [viewController isKindOfClass:[GBACheatManagerViewController class]])
    {
        GBAPresentOverlayViewControllerAnimator *animator = [[GBAPresentOverlayViewControllerAnimator alloc] init];
        return animator;
    }
    
    return nil;
}

- (void)prepareForPresentingTranslucentViewController
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        // Theoretically, I should put the blurring logic here and not in the transition itself, but yeah that doesn't work. With the 7 << 16 UIViewAnimationOption, it doesn't animate alongside it correctly
    }
    else
    {
        [self blurWithInitialAlpha:0.0];
        
        id<UIViewControllerTransitionCoordinator> transitionCoordinatior = [self transitionCoordinator];
        [transitionCoordinatior animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [self setBlurAlpha:1.0];
        } completion:nil];
    }
}

- (void)prepareForDismissingTranslucentViewController
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        // Theoretically, I should put the blurring logic here and not in the transition itself, but yeah that doesn't work. With the 7 << 16 UIViewAnimationOption, it doesn't animate alongside it correctly
    }
    else
    {
        id<UIViewControllerTransitionCoordinator> transitionCoordinatior = [self transitionCoordinator];
        [transitionCoordinatior animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [self setBlurAlpha:0.0];
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [self removeBlur];
        }];
    }
}

#pragma mark - GBAROMTableViewControllerAppearanceDelegate

- (void)romTableViewControllerWillDisappear:(GBAROMTableViewController *)romTableViewController
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && romTableViewController.presentedViewController == nil)
    {
        [self resumeEmulation];
    }
}

#pragma mark - App Status

- (void)willResignActive:(NSNotification *)notification
{
    if (![[GBALinkManager sharedManager] isLinkConnected])
    {
        [self pauseEmulationAndStayPaused:NO];
    }
}

- (void)didBecomeActive:(NSNotification *)notification
{
    if (!self.stayPaused)
    {
        [self resumeEmulation];
    }
}

- (void)didEnterBackground:(NSNotification *)notification
{
    if ([self shouldAutosave])
    {
        [self updateAutosaveState];
    }
    
    // Only save GBC games; saving some GBA games (such as Wario Ware Twisted) can erase the save file if saved here (due to RTC emulation, I'm guessing, even though Pokemon games work fine)
    if (self.rom && self.rom.type == GBAROMTypeGBC && !self.preventSavingROMSaveData)
    {
        [[GBAEmulatorCore sharedCore] writeSaveFileForCurrentROMToDisk];
    }
    
    [[GBASyncManager sharedManager] synchronize];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    // Check didBecomeActive:
    
    // Only save GBC games; saving some GBA games (such as Wario Ware Twisted) can erase the save file if saved here (due to RTC emulation, I'm guessing, even though Pokemon games work fine)
    if (self.rom && self.rom.type == GBAROMTypeGBC && !self.preventSavingROMSaveData)
    {
        [[GBAEmulatorCore sharedCore] writeSaveFileForCurrentROMToDisk];
    }
    
    [[GBASyncManager sharedManager] synchronize];
}

#pragma mark - Layout

- (BOOL)shouldAutorotate
{
    BOOL pausedEmulation = self.pausedEmulation;
    
    if (self.shouldResumeEmulationAfterRotatingInterface)
    {
        self.shouldResumeEmulationAfterRotatingInterface = NO;
        [self resumeEmulation];
    }
    
    // Rotate if we haven't locked the orientation, and if we're either not using the gyro, or using the gyro and the emulation is paused
    return !self.interfaceOrientationLocked && (!self.usingGyroscope || (self.usingGyroscope && pausedEmulation));
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    // No way to set constraints in relation to top of superview in Interface Builder, only Top Layout Guide. Since we show and hide the status bar, this causes the emulation screen to jump
    // This way, the screen stays in place regardless of whether the status bar is showing or not
    NSArray *array = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[screenContainerView]" options:0 metrics:0 views:@{@"screenContainerView" : self.screenContainerView}];
    [self.view addConstraints:array];
}

#define BLURRED_SNAPSHOT_TAG 17
#define CONTROLLER_SNAPSHOT_TAG 15

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if ([self.view viewWithTag:CONTROLLER_SNAPSHOT_TAG]) // Prevents this method from being called twice because Apple is stupid and iOS 8 beta 3 calls all rotation methods twice
    {
        return;
    }
    
    UIView *controllerSnapshot = [self.controllerView snapshotViewAfterScreenUpdates:NO];
    controllerSnapshot.frame = self.controllerView.frame;
    controllerSnapshot.tag = CONTROLLER_SNAPSHOT_TAG;
    controllerSnapshot.alpha = 1.0; // Snapshots take on the alpha of snapshotted view; if the original view was 0.7, 1.0 for the snapshot view will appear as if it was 0.7
    [self.view insertSubview:controllerSnapshot aboveSubview:self.controllerView];
    
    if (self.blurringContents)
    {
        self.emulatorScreen.hidden = YES;
        self.controllerView.hidden = YES;
        
        UIView *blurredSnapshot = [self.blurredContentsImageView snapshotViewAfterScreenUpdates:NO];
        blurredSnapshot.frame = self.blurredContentsImageView.frame;
        blurredSnapshot.tag = BLURRED_SNAPSHOT_TAG;
        blurredSnapshot.alpha = 1.0;
        
        [self.view addSubview:blurredSnapshot];
        self.blurredContentsImageView.image = [self blurredViewImageForInterfaceOrientation:toInterfaceOrientation drawController:YES];
    }
    
    [self updateControllerSkinForInterfaceOrientation:toInterfaceOrientation];
    
    self.controllerView.alpha = 0.0;
    //self.blurredContentsImageView.alpha = 0.0;
    
    // Possible iOS 7 bug? Attempting to set this in willAnimateRotationToInterfaceOrientation:duration: simply overrides the above setting of opacity
    // This way, it is definitely animated
    [UIView animateWithDuration:duration animations:^{
        self.controllerView.alpha = 1.0;
        self.blurredContentsImageView.alpha = 1.0;
    }];
    
    if (self.pausedActionSheet && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [self.pausedActionSheet dismissWithClickedButtonIndex:0 animated:NO];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    UIView *controllerSnapshot = [self.view viewWithTag:CONTROLLER_SNAPSHOT_TAG];
    controllerSnapshot.alpha = 0.0;
    controllerSnapshot.frame = self.controllerView.frame;
    
    UIView *blurredSnapshot = [self.view viewWithTag:BLURRED_SNAPSHOT_TAG];
    blurredSnapshot.alpha = 0.0;
    blurredSnapshot.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
    
    self.blurredContentsImageView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
    
    // Doesn't seem to work as of 7.0.2; overrides setting of alpha in willRotateToInterfaceOrientation:duration:, so no animation occurs
    //self.controllerView.alpha = 1.0;
    //self.blurredControllerImageView.alpha = 1.0;
    
    [self updateEmulatorScreenFrame];
    
    [self updateFilter];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    UIView *controllerSnapshot = [self.view viewWithTag:CONTROLLER_SNAPSHOT_TAG];
    [controllerSnapshot removeFromSuperview];
    
    UIView *blurredSnapshot = [self.view viewWithTag:BLURRED_SNAPSHOT_TAG];
    [blurredSnapshot removeFromSuperview];
    
    if (self.blurringContents)
    {
        self.emulatorScreen.hidden = NO;
        self.controllerView.hidden = NO;
    }
    
    if (self.shouldResumeEmulationAfterRotatingInterface)
    {
        [self resumeEmulation];
    }
    
    if (self.pausedActionSheet && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        // Below code used in controllerInputDidPressPauseButton as well, except with a selectionHandler
        
        CGRect rect = [self.controllerView.controllerSkin frameForMapping:GBAControllerSkinMappingMenu orientation:self.controllerView.orientation controllerDisplaySize:self.view.window.bounds.size useExtendedEdges:NO];
        
        CGRect convertedRect = [self.view convertRect:rect fromView:self.controllerView];
        
        CGFloat middleSectionStart = CGRectGetWidth(self.view.bounds) * (1.0/3.0);
        CGFloat middleSectionEnd = CGRectGetWidth(self.view.bounds) * (2.0/3.0);
        
        // Button is in the middle third of the screen, so we make sure it centers the popup instead of putting it off to the side as it sometimes does
        if (CGRectGetMidX(convertedRect) > middleSectionStart && CGRectGetMidX(convertedRect) < middleSectionEnd)
        {
            convertedRect.origin.x = 0;
            convertedRect.size.width = self.controllerView.bounds.size.width;
        }
        
        [self.pausedActionSheet showFromRect:convertedRect inView:self.view animated:YES];
    }
}

- (void)viewWillLayoutSubviews
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        [UIView animateWithDuration:0.4 animations:^{
            if (![[self.view constraints] containsObject:self.portraitBottomLayoutConstraint])
            {
                [self.view addConstraint:self.portraitBottomLayoutConstraint];
            }
        }];
    }
    else
    {
        [UIView animateWithDuration:0.4 animations:^{
            if ([[self.view constraints] containsObject:self.portraitBottomLayoutConstraint])
            {
                [self.view removeConstraint:self.portraitBottomLayoutConstraint];
            }
        }];
    }
}

- (void)updateControllerSkinForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (self.externalController)
    {
        GBAControllerSkin *invisibleSkin = [GBAControllerSkin invisibleSkin];
        
        self.controllerView.controllerSkin = invisibleSkin;
        
        if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
        {
            self.controllerView.orientation = GBAControllerSkinOrientationPortrait;
        }
        else
        {
            self.controllerView.orientation = GBAControllerSkinOrientationLandscape;
        }
        
        return;
    }
    
    NSString *defaultSkinIdentifier = nil;
    NSString *skinsKey = nil;
    GBAControllerSkinType skinType = GBAControllerSkinTypeGBA;
    
    switch (self.rom.type)
    {
        case GBAROMTypeGBA:
            defaultSkinIdentifier = [@"GBA/" stringByAppendingString:GBADefaultSkinIdentifier];
            skinsKey = GBASettingsGBASkinsKey;
            skinType = GBAControllerSkinTypeGBA;
            break;
            
        case GBAROMTypeGBC:
            defaultSkinIdentifier = [@"GBC/" stringByAppendingString:GBADefaultSkinIdentifier];
            skinsKey = GBASettingsGBCSkinsKey;
            skinType = GBAControllerSkinTypeGBC;
            break;
    }
    
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        NSString *identifier = [[NSUserDefaults standardUserDefaults] objectForKey:skinsKey][@"portrait"];
        GBAControllerSkin *controller = [GBAControllerSkin controllerSkinWithContentsOfFile:[self filepathForSkinIdentifier:identifier]];
        UIImage *image = [controller imageForOrientation:GBAControllerSkinOrientationPortrait];
        
        if (image == nil)
        {
            controller = [GBAControllerSkin defaultControllerSkinForSkinType:skinType];
            
            NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:skinsKey] mutableCopy];
            skins[@"portrait"] = defaultSkinIdentifier;
            [[NSUserDefaults standardUserDefaults] setObject:skins forKey:skinsKey];
        }
        
        self.controllerView.controllerSkin = controller;
        self.controllerView.orientation = GBAControllerSkinOrientationPortrait;
        
        BOOL translucent = [self.controllerView.controllerSkin isTranslucentForOrientation:self.controllerView.orientation];
        
        if (translucent)
        {
            self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
        }
        else
        {
            self.controllerView.skinOpacity = 1.0f;
        }
        
    }
    else
    {
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:skinsKey][@"landscape"];
        GBAControllerSkin *controller = [GBAControllerSkin controllerSkinWithContentsOfFile:[self filepathForSkinIdentifier:name]];
        UIImage *image = [controller imageForOrientation:GBAControllerSkinOrientationLandscape];
        
        if (image == nil)
        {
            controller = [GBAControllerSkin defaultControllerSkinForSkinType:skinType];
            
            NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:skinsKey] mutableCopy];
            skins[@"landscape"] = defaultSkinIdentifier;
            [[NSUserDefaults standardUserDefaults] setObject:skins forKey:skinsKey];
        }
        
        self.controllerView.controllerSkin = controller;
        self.controllerView.orientation = GBAControllerSkinOrientationLandscape;
        
        BOOL translucent = [self.controllerView.controllerSkin isTranslucentForOrientation:self.controllerView.orientation];
        
        if (translucent)
        {
            self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
        }
        else
        {
            self.controllerView.skinOpacity = 1.0f;
        }
    }
    
    if ([self.controllerView.controllerSkin debug])
    {
        [self.controllerView showButtonRects];
    }
    else
    {
        [self.controllerView hideButtonRects];
    }
}

- (void)updateEmulatorScreenFrame
{
    if (self.rom == nil)
    {
        return;
    }
    
    if (![self isAirplaying])
    {
        CGRect screenRect = [self.controllerView.controllerSkin frameForMapping:GBAControllerSkinMappingScreen orientation:self.controllerView.orientation controllerDisplaySize:self.view.bounds.size];
        
        // In case we're coming back from AirPlaying
        if (![self.screenContainerView.constraints containsObject:self.screenHorizontalCenterLayoutConstraint])
        {
            [self.screenContainerView addConstraint:self.screenHorizontalCenterLayoutConstraint];
        }
        
        if (![self.screenContainerView.constraints containsObject:self.screenVerticalCenterLayoutConstraint])
        {
            [self.screenContainerView addConstraint:self.screenVerticalCenterLayoutConstraint];
        }
        
        if (CGRectIsEmpty(screenRect) || self.externalController)
        {
            [UIView animateWithDuration:0.4 animations:^{
                self.screenHorizontalCenterLayoutConstraint.constant = 0;
                self.screenVerticalCenterLayoutConstraint.constant = 0;
            }];
            
            [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.screenContainerView.bounds.size] screen:[UIScreen mainScreen]];
        }
        else
        {
            [UIView animateWithDuration:0.4 animations:^{
                CGPoint center = CGPointMake(CGRectGetMidX(self.screenContainerView.bounds), CGRectGetMidY(self.screenContainerView.bounds));
                CGPoint screenRectCenter = CGPointMake(CGRectGetMinX(screenRect) + CGRectGetWidth(screenRect) / 2.0,
                                                       CGRectGetMinY(screenRect) + CGRectGetHeight(screenRect) / 2.0);
                
                self.screenHorizontalCenterLayoutConstraint.constant = center.x - screenRectCenter.x;
                self.screenVerticalCenterLayoutConstraint.constant = center.y - screenRectCenter.y;
            }];
            
            self.emulatorScreen.frame = screenRect;
            
            [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:screenRect.size screen:[UIScreen mainScreen]];
        }
    }
    else
    {
        [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.airplayWindow.bounds.size] screen:self.airplayWindow.screen];
        
    }
    
    [self.emulatorScreen invalidateIntrinsicContentSize];
    
    if (self.emulatorScreen.eaglView == nil)
    {
        self.emulatorScreen.eaglView = [[GBAEmulatorCore sharedCore] eaglView];
    }
}

- (void)viewDidLayoutSubviews
{
    // possible iOS 7 bug? self.screenContainerView.bounds still has old bounds when this method is called, so we can't really do anything.    
}

- (void)refreshLayout
{
    [self updateFilter];
    
    [self updateControllerSkinForInterfaceOrientation:self.interfaceOrientation];
    
    [self.view updateConstraintsIfNeeded];
    [self.view layoutIfNeeded];
    
    if (self.blurringContents)
    {
        self.blurredContentsImageView.image = [self blurredViewImageForInterfaceOrientation:self.interfaceOrientation drawController:YES];
        self.blurredContentsImageView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
    }
    
    if (self.rom != nil)
    {
        [self updateEmulatorScreenFrame];
    }
}

#pragma mark - Emulation

- (void)launchGameWithCompletion:(void (^)(void))completionBlock
{
    // Now we handle switching ROMs
    
    if (self.selectingSustainedButton)
    {
        [self exitSustainButtonSelectionMode];
    }
    
    UIViewController *presentedViewController = self.presentedViewController;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [self.romTableViewController dismissViewControllerAnimated:YES completion:nil];
        
        [(GBASplitViewController *)self.splitViewController hideROMTableViewControllerWithAnimation:YES];
    }
    else
    {
        // If there are two presented view controllers, the topmost one is not transparent so we can remove the blur
        if (presentedViewController.presentedViewController)
        {
            [self removeBlur];
        }
    }
        
    [self dismissViewControllerAnimated:YES completion:^{
        [self resumeEmulation]; // In case ROM didn't change
        
        if (completionBlock)
        {
            completionBlock();
        }
    }];
}

- (void)startEmulation
{
    [self stopEmulation]; // Stop previously running ROM
    
    self.pausedEmulation = NO;
    
    _romStartTime = CFAbsoluteTimeGetCurrent();
    
    rst_dispatch_sync_on_main_thread(^{
        [[GBAEmulatorCore sharedCore] startEmulation];
    });
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)stopEmulation
{
    rst_dispatch_sync_on_main_thread(^{
         [[GBAEmulatorCore sharedCore] endEmulation];
    });
    
    self.pausedEmulation = NO;
    
    [self resumeEmulation]; // In case the ROM never unpaused (just keep it here please)
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)pauseEmulation
{
    [self pauseEmulationAndStayPaused:YES];
}

- (void)pauseEmulationAndStayPaused:(BOOL)stayPaused
{
    self.pausedEmulation = YES;
    
    if (!self.stayPaused)
    {
        self.stayPaused = stayPaused;
    }
    
    [self.emulatorScreen.introAnimationLayer.player pause];
    
    if ([self isPlayingIntroAnimation])
    {
        return;
    }
    
    // Only save GBC games; saving some GBA games (such as Wario Ware Twisted) can erase the save file if saved here (due to RTC emulation, I'm guessing, even though Pokemon games work fine)
    if (self.rom && self.rom.type == GBAROMTypeGBC && !self.preventSavingROMSaveData)
    {
        [[GBAEmulatorCore sharedCore] writeSaveFileForCurrentROMToDisk];
    }
    
    rst_dispatch_sync_on_main_thread(^{
        [[GBAEmulatorCore sharedCore] pauseEmulation];
    });
    
    // iOS 7 bug: dims screen immediately if it has been more than 45 seconds since last touch
   // [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)resumeEmulation
{
    if ([self isShowingGyroscopeAlert])
    {
        return;
    }
    
    self.shouldResumeEmulationAfterRotatingInterface = NO;
    
    self.pausedEmulation = NO;
    self.stayPaused = NO;
    
    if (self.rom == nil)
    {
        return;
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    [self.emulatorScreen.introAnimationLayer.player play];
    
    if ([self isPlayingIntroAnimation])
    {
        return;
    }
    
    [[GBAEmulatorCore sharedCore] resumeEmulation];
    [[GBAEmulatorCore sharedCore] pressButtons:self.sustainedButtonSet];
    
    if ([[GBALinkManager sharedManager] isLinkConnected])
    {
        [self stopFastForwarding];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)updateFilter
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && [[UIScreen mainScreen] scale] < 3.0 && UIInterfaceOrientationIsPortrait(self.interfaceOrientation) && self.rom.type == GBAROMTypeGBA && ![self isAirplaying])
    {
        [[GBAEmulatorCore sharedCore] applyEmulationFilter:GBAEmulationFilterLinear];
    }
    else
    {
        [[GBAEmulatorCore sharedCore] applyEmulationFilter:GBAEmulationFilterNone];
    }
}

#pragma mark - Notifications

- (void)romDidSaveData:(NSNotification *)notification
{
    GBAROM *rom = [notification object];
    
    if (rom == nil)
    {
        return;
    }
    
    NSData *saveData = [[NSData alloc] initWithContentsOfFile:rom.saveFileFilepath];
    
    if (![self.cachedSaveData isEqualToData:saveData])
    {
        self.cachedSaveData = saveData;
        
        if (![self.rom event])
        {
            [[GBASyncManager sharedManager] prepareToUploadSaveFileForROM:rom];
        }
        
        DLog(@"New save data!");
    }
}

#pragma mark - Syncing

- (void)hasNewDropboxSaveForCurrentGameFromDropbox:(NSNotification *)notification
{
    self.preventSavingROMSaveData = YES;
    
    [[GBASyncManager sharedManager] setShouldShowSyncingStatus:YES];
    
    GBASyncingDetailViewController *syncingDetailViewController = [[GBASyncingDetailViewController alloc] initWithROM:self.rom];
    syncingDetailViewController.delegate = self;
    syncingDetailViewController.showDoneButton = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self prepareAndPresentViewController:syncingDetailViewController];
        
        [self.rom setNewlyConflicted:NO];
    });
}

- (void)dismissSyncView:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)shouldRestartCurrentGame:(NSNotification *)notification
{
    if ([self shouldAutosave])
    {
        [self updateAutosaveState];
    }
    
    // Restart game
    [self setRom:self.rom];
    
    self.stayPaused = YES;
    
    // Let the ROM run a little bit before we freeze it
    double delayInSeconds = 0.3;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self pauseEmulation];
        
        [self refreshLayout];
    });
}

- (void)syncManagerFinishedSync:(NSNotification *)notification
{
    if (self.rom == nil)
    {
        return;
    }
    
    [[GBAEmulatorCore sharedCore] updateCheats];
}

- (void)syncingDetailViewControllerWillDismiss:(GBASyncingDetailViewController *)syncingDetailViewController
{
    [self prepareForDismissingPresentedViewController:syncingDetailViewController];
}

#pragma mark - Presenting/Dismissing External View Controllers

- (void)prepareAndPresentViewController:(UIViewController *)viewController
{
    if (![self selectingSustainedButton])
    {
        [self pauseEmulation];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        if (self.blurringContents)
        {
            [self refreshLayout];
        }
        else
        {
            
            if (![self selectingSustainedButton])
            {
                [self blurWithInitialAlpha:0.0];
                
                [UIView animateWithDuration:0.3 animations:^{
                    [self setBlurAlpha:1.0];
                }];
            }
            
        }
    }
    
    
    UINavigationController *navigationController = (UINavigationController *)viewController;
    
    if (![viewController isKindOfClass:[UINavigationController class]])
    {
        navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(viewController);
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    else
    {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
    
    UIViewController *presentingViewController = self;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        GBASplitViewController *splitViewController = (GBASplitViewController *)self.splitViewController;
        
        if ([splitViewController romTableViewControllerIsVisible])
        {
            presentingViewController = splitViewController.romTableViewController;
        }
    }
    
    while (presentingViewController.presentedViewController)
    {
        presentingViewController = presentingViewController.presentedViewController;
    }
    
    [presentingViewController presentViewController:navigationController animated:YES completion:NULL];
    
    [self.pausedActionSheet dismissWithClickedButtonIndex:0 animated:YES];
    self.pausedActionSheet = nil;
}

- (void)prepareForDismissingPresentedViewController:(UIViewController *)dismissedViewController
{
    UIViewController *presentedViewController = self.presentedViewController;
    if ([presentedViewController isKindOfClass:[UINavigationController class]])
    {
        presentedViewController = [[(UINavigationController *)presentedViewController viewControllers] firstObject];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        // Only hide status bar if the syncingDetailViewController was the modal view controller. If it isn't, the status bar should stay
        if (presentedViewController == dismissedViewController)
        {
            [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
        }
        
        // Used primarily to update the blurring, but can't help to update everything
        [self refreshLayout];
    }
    
    self.preventSavingROMSaveData = NO;
    
    if (presentedViewController == dismissedViewController)
    {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            if (![(GBASplitViewController *)self.splitViewController romTableViewControllerIsVisible])
            {
                if (![self selectingSustainedButton])
                {
                    [UIView animateWithDuration:0.3 animations:^{
                        [self setBlurAlpha:0.0];
                    } completion:^(BOOL finished) {
                        [self removeBlur];
                    }];
                    
                    [self resumeEmulation];
                }
            }
        }
        else
        {
            if (![self selectingSustainedButton])
            {
                [self resumeEmulation];
            }
        }
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        if (self.presentedViewController != self.romTableViewController.navigationController)
        {
            [[GBASyncManager sharedManager] setShouldShowSyncingStatus:NO];
        }
    }
    else
    {
        if (![(GBASplitViewController *)self.splitViewController romTableViewControllerIsVisible])
        {
            [[GBASyncManager sharedManager] setShouldShowSyncingStatus:NO];
        }
    }
}

#pragma mark - Blurring

- (void)blurWithInitialAlpha:(CGFloat)alpha
{
    [self.blurredContentsImageView removeFromSuperview];
    
    self.blurredContentsImageView = ({
        UIImage *blurredImage = [self blurredViewImageForInterfaceOrientation:self.interfaceOrientation drawController:YES];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:blurredImage];
        imageView.clipsToBounds = YES;
        imageView.translatesAutoresizingMaskIntoConstraints = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [imageView sizeToFit];
        imageView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
        imageView.contentMode = UIViewContentModeBottom;
        imageView.alpha = alpha;
        [self.view addSubview:imageView];
        imageView;
    });
    
    [self.view addSubview:self.blurredContentsImageView];
    
    self.blurringContents = YES;
}

- (void)removeBlur
{
    self.blurringContents = NO;
    
    self.controllerView.hidden = NO;
    
    [self.blurredContentsImageView removeFromSuperview];
    self.blurredContentsImageView = nil;
}

- (void)setBlurAlpha:(CGFloat)blurAlpha
{
    _blurAlpha = blurAlpha;
    self.blurredContentsImageView.alpha = blurAlpha;
}

- (UIImage *)blurredViewImageForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation drawController:(BOOL)drawController
{
    CGSize viewSize = [[[UIApplication sharedApplication] delegate] window].bounds.size;
    NSString *userDefaultsSkinOrientation = nil;
    GBAControllerSkinOrientation skinOrientation = GBAControllerSkinOrientationPortrait;
    
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        if (viewSize.width > viewSize.height)
        {
            viewSize = CGSizeMake(viewSize.height, viewSize.width);
        }
        
        userDefaultsSkinOrientation = @"portrait";
        skinOrientation = GBAControllerSkinOrientationPortrait;
    }
    else
    {
        if (viewSize.height > viewSize.width)
        {
            viewSize = CGSizeMake(viewSize.height, viewSize.width);
        }
        
        userDefaultsSkinOrientation = @"landscape";
        skinOrientation = GBAControllerSkinOrientationLandscape;
    }
    
    GBAControllerSkin *controllerSkin = nil;
    UIImage *controllerSkinImage = nil;
    
    if (self.externalController)
    {
        controllerSkin = [GBAControllerSkin invisibleSkin];
        controllerSkinImage = nil;
    }
    else
    {
        NSString *defaultSkinIdentifier = nil;
        NSString *skinsKey = nil;
        GBAControllerSkinType skinType = GBAControllerSkinTypeGBA;
        
        switch (self.rom.type)
        {
            case GBAROMTypeGBA:
                defaultSkinIdentifier = [@"GBA/" stringByAppendingString:GBADefaultSkinIdentifier];
                skinsKey = GBASettingsGBASkinsKey;
                skinType = GBAControllerSkinTypeGBA;
                break;
                
            case GBAROMTypeGBC:
                defaultSkinIdentifier = [@"GBC/" stringByAppendingString:GBADefaultSkinIdentifier];
                skinsKey = GBASettingsGBCSkinsKey;
                skinType = GBAControllerSkinTypeGBC;
                break;
        }
        
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:skinsKey][userDefaultsSkinOrientation];
        
        controllerSkin = [GBAControllerSkin controllerSkinWithContentsOfFile:[self filepathForSkinIdentifier:name]];
        controllerSkinImage = [controllerSkin imageForOrientation:skinOrientation];
        
        if (controllerSkinImage == nil)
        {
            controllerSkin = [GBAControllerSkin defaultControllerSkinForSkinType:skinType];
            
            NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:skinsKey] mutableCopy];
            skins[userDefaultsSkinOrientation] = defaultSkinIdentifier;
            [[NSUserDefaults standardUserDefaults] setObject:skins forKey:skinsKey];
            
            controllerSkinImage = [controllerSkin imageForOrientation:skinOrientation];
        }
    }
    
    CGFloat controllerAlpha = 1.0f;
    if ([controllerSkin isTranslucentForOrientation:skinOrientation])
    {
        controllerAlpha = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
    }
    
    CGSize controllerDisplaySize = [controllerSkin frameForMapping:GBAControllerSkinMappingControllerImage orientation:skinOrientation controllerDisplaySize:viewSize].size;
    CGSize screenContainerSize = CGSizeZero;
    CGRect controllerRect = CGRectZero;
    
    CGSize screenSize = [self screenSizeForContainerSize:viewSize];
    
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        screenContainerSize = CGSizeMake(viewSize.width, viewSize.height - controllerDisplaySize.height);
        
        controllerRect = CGRectMake((viewSize.width - controllerDisplaySize.width) / 2.0f,
                                 screenContainerSize.height,
                                 controllerDisplaySize.width,
                                 controllerDisplaySize.height);
    }
    else
    {
        screenContainerSize = CGSizeMake(viewSize.width, viewSize.height);
        
        controllerRect = CGRectMake((screenContainerSize.width - controllerDisplaySize.width) / 2.0,
                                 0,
                                 controllerDisplaySize.width,
                                 controllerDisplaySize.height);
    }
    

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(viewSize.width, viewSize.height), YES, 0.5);
    
    if (self.emulatorScreen.eaglView && ![self isAirplaying]) // As of iOS 7.0.3 crashes when attempting to draw the empty emulatorScreen
    {
        CGRect screenRect = [controllerSkin frameForMapping:GBAControllerSkinMappingScreen orientation:skinOrientation controllerDisplaySize:viewSize];
        
        if (CGRectIsEmpty(screenRect) || self.externalController)
        {
            [self.emulatorScreen drawViewHierarchyInRect:CGRectMake((screenContainerSize.width - screenSize.width) / 2.0,
                                                                    (screenContainerSize.height - screenSize.height) / 2.0,
                                                                    screenSize.width,
                                                                    screenSize.height) afterScreenUpdates:NO];
        }
        else
        {
            [self.emulatorScreen drawViewHierarchyInRect:screenRect afterScreenUpdates:NO];
        }
    }
    
    if (drawController)
    {
        [controllerSkinImage drawInRect:controllerRect blendMode:kCGBlendModeNormal alpha:controllerAlpha];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIColor *tintColor = [UIColor colorWithWhite:0.11 alpha:0.73];
    return [image applyBlurWithRadius:10 tintColor:tintColor saturationDeltaFactor:1.8 maskImage:nil];
}

#pragma mark - Getters/Setters

- (void)setRom:(GBAROM *)rom
{
    // Only save data if the new rom is different; otherwise, we may just be resetting the ROM after downloading a save from Dropbox in which case we *don't* want to save data.
    if (self.rom && self.rom.type == GBAROMTypeGBC && ![_rom isEqual:rom])
    {
        [[GBAEmulatorCore sharedCore] writeSaveFileForCurrentROMToDisk];
    }
        
    _rom = rom;
    
    self.usingGyroscope = NO;
    
    self.cachedSaveData = [[NSData alloc] initWithContentsOfFile:rom.saveFileFilepath];
    
    // Changing ROM should be done on main thread
    rst_dispatch_sync_on_main_thread(^{
        
        [self refreshLayout]; // Must go before resumeEmulation
        
        if (_rom) // If there was a previous ROM make sure to unpause it!
        {
            [self resumeEmulation];
        }
        
        [self updateFilter];
        
        [self stopFastForwarding];
        
        NSSet *sustainedButtons = [self.sustainedButtonSet copy];
        self.sustainedButtonSet = nil;
        
        [[GBAEmulatorCore sharedCore] releaseButtons:sustainedButtons];
        [[GBAEmulatorCore sharedCore] setRom:self.rom];
        
        if (rom)
        {
            [self startEmulation];
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsIntroAnimationKey])
            {
                [self pauseEmulation];
                [self playIntroAnimation];
                
                if (self.showingGyroscopeAlert)
                {
                    [self pauseEmulation];
                }
                
            }
        }
        else
        {
            [self stopEmulation];
            
            self.emulatorScreen.eaglView = nil;
            
            [self refreshLayout];
        }
        
        [self updateFilter];
    });
}


- (BOOL)isAirplaying
{
    return (self.airplayWindow != nil);
}

- (BOOL)isExternalControllerConnected
{
    return (self.externalController != nil);
}


@end











