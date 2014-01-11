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
#import "UIScreen+Widescreen.h"
#import "GBAExternalController.h"
#import "GBASyncingDetailViewController.h"
#import "GBAAppDelegate.h"
#import "GBAEventDistributionViewController.h"

#import <GameController/GameController.h>

#if !(TARGET_IPHONE_SIMULATOR)
#import "GBAEmulatorCore.h"
#endif

#import "UIActionSheet+RSTAdditions.h"
#import "UIAlertView+RSTAdditions.h"
#include <sys/sysctl.h>

static GBAEmulationViewController *_emulationViewController;

@interface GBAEmulationViewController () <GBAControllerInputDelegate, UIViewControllerTransitioningDelegate, GBASaveStateViewControllerDelegate, GBACheatManagerViewControllerDelegate, GBASyncingDetailViewControllerDelegate, GBAEventDistributionViewControllerDelegate> {
    CFAbsoluteTime _romStartTime;
    CFAbsoluteTime _romPauseTime;
    NSInteger _sustainButtonFrameCount;
}

@property (weak, nonatomic) IBOutlet GBAEmulatorScreen *emulatorScreen;
@property (strong, nonatomic) IBOutlet GBAControllerView *controllerView;
@property (strong, nonatomic) GBAExternalController *externalController;
@property (strong, nonatomic) UIActionSheet *pausedActionSheet;
@property (weak, nonatomic) IBOutlet UIView *screenContainerView;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (copy, nonatomic) NSSet *buttonsToPressForNextCycle;
@property (strong, nonatomic) UIWindow *airplayWindow;
@property (strong, nonatomic) GBAROMTableViewController *romTableViewController;
@property (strong, nonatomic) UIImageView *splashScreenImageView;
@property (strong, nonatomic) GBAEventDistributionViewController *eventDistributionViewController;
@property (copy, nonatomic) NSDictionary *eventDistributionROMs;

@property (assign, nonatomic) BOOL pausedEmulation;
@property (assign, nonatomic) BOOL stayPaused;
@property (assign, nonatomic) BOOL interfaceOrientationLocked;

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
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"emulationViewController"];
    if (self)
    {
        _emulationViewController = self;
        InstallUncaughtExceptionHandler();
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
        
    if ([[UIScreen screens] count] > 1)
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
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(romDidSaveData:) name:GBAROMDidSaveDataNotification object:nil];
#endif
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hasNewDropboxSaveForCurrentGameFromDropbox:) name:GBAHasNewDropboxSaveForCurrentGameFromDropboxNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldRestartCurrentGame:) name:GBAShouldRestartCurrentGameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncManagerFinishedSync:) name:GBASyncManagerFinishedSyncNotification object:[GBASyncManager sharedManager]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidConnect:) name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidConnect:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidDisconnect:) name:GCControllerDidDisconnectNotification object:nil];
    
    self.view.clipsToBounds = NO;
    
    // This isn't for FPS, remember? Keep it here stupid, it's for sustain button
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLink:)];
	[self.displayLink setFrameInterval:1];
	[self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    // Because we need to present the ROM Table View Controller stealthily
    self.splashScreenImageView = [[UIImageView alloc] init];
    self.splashScreenImageView.backgroundColor = [UIColor blackColor];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        if ([[UIScreen mainScreen] isWidescreen])
        {
            self.splashScreenImageView.image = [UIImage imageNamed:@"Default-568h"];
        }
        else
        {
            self.splashScreenImageView.image = [UIImage imageNamed:@"Default"];
        }
        
        [self.splashScreenImageView sizeToFit];
        
        [self.view addSubview:self.splashScreenImageView];
    }
    else
    {
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        {
            self.splashScreenImageView.image = [UIImage imageNamed:@"Default-Portrait"];
        }
        else
        {
            self.splashScreenImageView.image = [UIImage imageNamed:@"Default-Landscape"];
        }
        
        [self.splashScreenImageView sizeToFit];
        
        [self.splitViewController.view addSubview:self.splashScreenImageView];
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] applyEmulationFilter:GBAEmulationFilterLinear];
#endif
    
    [self updateSettings:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.splashScreenImageView)
    {
        DLog(@"App did launch");
        
        self.eventDistributionROMs = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"eventDistributionROMs" ofType:@"plist"]];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            self.romTableViewController = [[GBAROMTableViewController alloc] init];
            UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(self.romTableViewController);
            navigationController.modalPresentationStyle = UIModalPresentationCustom;
            navigationController.transitioningDelegate = self;
            
            [self presentViewController:navigationController animated:YES completion:^{
                [self.splashScreenImageView removeFromSuperview];
                self.splashScreenImageView = nil;
                
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
            
            self.splashScreenImageView.transform = transform;
            self.splashScreenImageView.frame = [[UIScreen mainScreen] bounds];
            
            UIWindow *window = [[UIApplication sharedApplication] keyWindow];
            [window addSubview:self.splashScreenImageView];
            
            [UIView animateWithDuration:0.5 animations:^{
                self.splashScreenImageView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [self.splashScreenImageView removeFromSuperview];
                self.splashScreenImageView = nil;
                
                if (self.rom)
                {
                    GBAROM *rom = self.rom;
                    self.rom = nil;
                    [self.romTableViewController startROM:rom];
                }
            }];
        }
        
        self.romTableViewController.emulationViewController = self;
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
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && self.rom == nil)
    {
        return NO;
    }
    
    return YES;
}

#pragma mark - Private

- (void)handleDisplayLink:(CADisplayLink *)displayLink
{
    if (self.buttonsToPressForNextCycle)
    {
        _sustainButtonFrameCount++;
        
        if (_sustainButtonFrameCount > 1)
        {
            _sustainButtonFrameCount = 0;
            
#if !(TARGET_IPHONE_SIMULATOR)
            [[GBAEmulatorCore sharedCore] pressButtons:self.buttonsToPressForNextCycle];
#endif
            
            self.buttonsToPressForNextCycle = nil;
        }
    }
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

#pragma mark - Airplay

- (void)screenDidConnect:(NSNotification *)notification
{
    if ([self isAirplaying])
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
    
    self.externalController = [GBAExternalController externalControllerWithController:notification.object];
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
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] releaseButtons:sustainedButtons];
#endif
        
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
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] pressButtons:buttons];
#endif
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
    
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] releaseButtons:buttons];
#endif
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

    [self pauseEmulation];
    
    
    NSString *returnToMenuButtonTitle = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        returnToMenuButtonTitle = NSLocalizedString(@"Show ROM List", @"");
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
    if ([self.rom isEvent])
    {
        if ([self numberOfCPUCoresForCurrentDevice] == 1)
        {
            self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
                                                                 delegate:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle:NSLocalizedString(@"Exit Event Distribution", @"")
                                                        otherButtonTitles:
                                      NSLocalizedString(@"Sustain Button", @""), nil];
        }
        else
        {
            self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
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
        if (eventDistributionCapableROM)
        {
            if ([self numberOfCPUCoresForCurrentDevice] == 1)
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
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
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
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
        else
        {
            if ([self numberOfCPUCoresForCurrentDevice] == 1)
            {
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
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
                self.pausedActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
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
    
    void (^selectionHandler)(UIActionSheet *actionSheet, NSInteger buttonIndex) = ^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
        
        if (buttonIndex == 0)
        {
            if ([self.rom isEvent])
            {
                [self finishEventDistribution];
            }
            else
            {
                [[GBASyncManager sharedManager] setShouldShowSyncingStatus:YES];
                [self returnToROMTableViewController];
            }
        }
        else {
            if ([self numberOfCPUCoresForCurrentDevice] == 1)
            {
                // Compensate for lack of Fast Forward button
                buttonIndex = buttonIndex + 1;
            }
            
            if ([self.rom isEvent] && buttonIndex > 1)
            {
                // We hide Save State, Load State, and Cheat Codes
                buttonIndex = buttonIndex + 3;
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
                if (eventDistributionCapableROM && ![self.rom isEvent])
                {
                    [self presentEventDistribution];
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
    }
    else
    {
        CGRect rect = [self.controllerView.controllerSkin rectForButtonRect:GBAControllerSkinRectMenu orientation:self.controllerView.orientation];
        
        CGRect convertedRect = [self.view convertRect:rect fromView:self.controllerView];
        
        // Create a rect that will make the action sheet appear ABOVE the menu button, not to the right
        convertedRect.origin.x = 0;
        convertedRect.size.width = self.controllerView.bounds.size.width;
        
        [self.pausedActionSheet showFromRect:convertedRect inView:self.view animated:YES selectionHandler:selectionHandler];
    }
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
    
    UILabel *instructionsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.emulatorScreen.bounds) - 20.0f, CGRectGetHeight(self.emulatorScreen.bounds) - 20.0f)];
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
    
    CGRect screenRect = [self.controllerView.controllerSkin rectForButtonRect:GBAControllerSkinRectScreen orientation:self.controllerView.orientation];
    
    if (CGRectIsEmpty(screenRect))
    {
        screenRect = self.screenContainerView.frame;
    }
    
    instructionsLabel.center = CGPointMake(CGRectGetMidX(screenRect), CGRectGetMidY(screenRect));
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && self.controllerView.orientation == GBAControllerSkinOrientationLandscape)
    {
        if (CGRectIsEmpty(screenRect) && self.externalController == nil) // With external controller, we want it to be centered
        {
            instructionsLabel.center = ({
                CGPoint center = instructionsLabel.center;
                center.y -= 45.0f;
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
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] releaseButtons:self.sustainedButtonSet];
#endif
    
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
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] startFastForwarding];
#endif
}

- (void)stopFastForwarding
{
    self.fastForwarding = NO;
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] stopFastForwarding];
#endif
}

#pragma mark - Save States

- (void)presentSaveStateMenuWithMode:(GBASaveStateViewControllerMode)mode
{
    NSString *filename = self.rom.name;
    
    GBASaveStateViewController *saveStateViewController = [[GBASaveStateViewController alloc] initWithROM:self.rom mode:mode];
    saveStateViewController.delegate = self;
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(saveStateViewController);
    
    [self blurWithInitialAlpha:0.0];
    
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
        
        [UIView animateWithDuration:0.3 animations:^{
            [self setBlurAlpha:1.0];
        }];
    }
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController willLoadStateWithFilename:(NSString *)filename
{
    if ([filename hasPrefix:@"autosave"] && [self shouldAutosave])
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

- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController didLoadStateWithFilename:(NSString *)filename
{
    if ([filename hasPrefix:@"autosave"] && [self shouldAutosave])
    {
        NSString *autosaveFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"autosave.sgm"];
        NSString *backupFilepath = [[self saveStateDirectory] stringByAppendingPathComponent:@"backup.sgm"];
        
        [[NSFileManager defaultManager] replaceItemAtURL:[NSURL fileURLWithPath:autosaveFilepath] withItemAtURL:[NSURL fileURLWithPath:backupFilepath] backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:nil error:nil];
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] updateCheats];
#endif
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
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"autosave"] && (_romPauseTime - _romStartTime >= 3.0f) && ![self.rom isEvent];
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
    
    NSString *romName = self.rom.uniqueName;
    NSString *directory = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"Save States/%@", romName]];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return directory;
}

#pragma mark - Cheats

- (void)presentCheatManager
{
    GBACheatManagerViewController *cheatManagerViewController = [[GBACheatManagerViewController alloc] initWithROM:self.rom];
    cheatManagerViewController.delegate = self;
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(cheatManagerViewController);
    
    [self blurWithInitialAlpha:0.0];
    
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
        
        [UIView animateWithDuration:0.3 animations:^{
            [self setBlurAlpha:1.0];
        }];
    }
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController willDismissCheatEditorViewController:(GBACheatEditorViewController *)cheatEditorViewController
{
    [self refreshLayout];
}

- (void)cheatManagerViewControllerWillDismiss:(GBACheatManagerViewController *)cheatManagerViewController
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

#pragma mark - Event Distribution

- (void)presentEventDistribution
{
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    
    GBAEventDistributionViewController *eventDistributionViewController = [[GBAEventDistributionViewController alloc] initWithROM:self.rom];
    eventDistributionViewController.delegate = self;
    eventDistributionViewController.emulationViewController = self;
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(eventDistributionViewController);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [self blurWithInitialAlpha:0.0];
        
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        
        [UIView animateWithDuration:0.3 animations:^{
            [self setBlurAlpha:1.0];
        }];
    }
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)finishEventDistribution
{
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(self.eventDistributionViewController) animated:YES completion:nil];
    
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

#pragma mark - Settings

- (void)updateSettings:(NSNotification *)notification
{    
    BOOL translucent = [[self.controllerView.controllerSkin dictionaryForOrientation:self.controllerView.orientation][@"translucent"] boolValue];
    
    if (translucent)
    {
        self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
    }
    else
    {
        self.controllerView.skinOpacity = 1.0f;
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
        if ([(GBAROMTableViewController *)viewController theme] == GBAThemedTableViewControllerThemeTranslucent)
        {
            GBAROMTableViewControllerAnimator *animator = [[GBAROMTableViewControllerAnimator alloc] init];
            animator.presenting = YES;
            return animator;
        }
        else
        {
            GBAInitialPresentROMTableViewControllerAnimator *animator = [[GBAInitialPresentROMTableViewControllerAnimator alloc] init];
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

#pragma mark - App Status

- (void)willResignActive:(NSNotification *)notification
{
    [self pauseEmulationAndStayPaused:NO];
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
    
    if (self.rom && !self.preventSavingROMSaveData)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] writeSaveFileForCurrentROMToDisk];
#endif
    }
    
    [[GBASyncManager sharedManager] synchronize];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    // Check didBecomeActive:
    
    if (self.rom && !self.preventSavingROMSaveData)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] writeSaveFileForCurrentROMToDisk];
#endif
    }
    
    [[GBASyncManager sharedManager] synchronize];
}

#pragma mark - Layout

- (BOOL)shouldAutorotate
{
    return !self.interfaceOrientationLocked;
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
    UIView *controllerSnapshot = [self.controllerView snapshotViewAfterScreenUpdates:NO];
    controllerSnapshot.frame = self.controllerView.frame;
    controllerSnapshot.tag = CONTROLLER_SNAPSHOT_TAG;
    controllerSnapshot.alpha = 1.0;
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
    
#if !(TARGET_IPHONE_SIMULATOR)
    GBAEmulationFilter filter = GBAEmulationFilterLinear;
    
    if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
    {
        filter = GBAEmulationFilterNone;
    }
    
    [[GBAEmulatorCore sharedCore] applyEmulationFilter:filter];
#endif
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
        
        BOOL translucent = [[controller dictionaryForOrientation:GBAControllerSkinOrientationPortrait][@"translucent"] boolValue];
        
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
        
        BOOL translucent = [[controller dictionaryForOrientation:GBAControllerSkinOrientationLandscape][@"translucent"] boolValue];
        
        if (translucent)
        {
            self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
        }
        else
        {
            self.controllerView.skinOpacity = 1.0f;
        }
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
        CGRect screenRect = [self.controllerView.controllerSkin screenRectForOrientation:self.controllerView.orientation];
        
        if (CGRectIsEmpty(screenRect) || self.externalController)
        {
            [UIView animateWithDuration:0.4 animations:^{
                if (![self.screenContainerView.constraints containsObject:self.screenHorizontalCenterLayoutConstraint])
                {
                    [self.screenContainerView addConstraint:self.screenHorizontalCenterLayoutConstraint];
                }
                
                if (![self.screenContainerView.constraints containsObject:self.screenVerticalCenterLayoutConstraint])
                {
                    [self.screenContainerView addConstraint:self.screenVerticalCenterLayoutConstraint];
                }
            }];
            
#if !(TARGET_IPHONE_SIMULATOR)
            [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.screenContainerView.bounds.size] screen:[UIScreen mainScreen]];
            [self.emulatorScreen invalidateIntrinsicContentSize];
#else
            
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            {
                self.emulatorScreen.bounds = CGRectMake(0, 0, 320, 240);
            }
            else
            {
                self.emulatorScreen.bounds = CGRectMake(0, 0, 480, 320);
            }
            
#endif
        }
        else
        {
            [UIView animateWithDuration:0.4 animations:^{
                if ([self.screenContainerView.constraints containsObject:self.screenHorizontalCenterLayoutConstraint])
                {
                    [self.screenContainerView removeConstraint:self.screenHorizontalCenterLayoutConstraint];
                }
                
                if ([self.screenContainerView.constraints containsObject:self.screenVerticalCenterLayoutConstraint])
                {
                    [self.screenContainerView removeConstraint:self.screenVerticalCenterLayoutConstraint];
                }
            }];
            
            
            self.emulatorScreen.frame = ({
                CGRect frame = self.emulatorScreen.frame;
                CGSize aspectSize = [self screenSizeForContainerSize:screenRect.size];
                
                frame.origin = CGPointMake(screenRect.origin.x + screenRect.size.width/2.0f - aspectSize.width/2.0f, screenRect.origin.y + screenRect.size.height/2.0f - aspectSize.height/2.0f);
                frame.size = aspectSize;
                
                frame;
            });
            self.emulatorScreen.center = CGPointMake(screenRect.origin.x + screenRect.size.width/2.0f, screenRect.origin.y + screenRect.size.height/2.0f);
            self.emulatorScreen.frame = screenRect;
            
#if !(TARGET_IPHONE_SIMULATOR)
            [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:screenRect.size screen:[UIScreen mainScreen]];
            [self.emulatorScreen invalidateIntrinsicContentSize];
#endif
            
        }
        
    }
    else
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.airplayWindow.bounds.size] screen:self.airplayWindow.screen];
        [self.emulatorScreen invalidateIntrinsicContentSize];
#endif
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    if (self.emulatorScreen.eaglView == nil)
    {
        self.emulatorScreen.eaglView = [[GBAEmulatorCore sharedCore] eaglView];
    }
#endif
}

- (void)viewDidLayoutSubviews
{
    // possible iOS 7 bug? self.screenContainerView.bounds still has old bounds when this method is called, so we can't really do anything.
    
    
}

- (void)refreshLayout
{
#if !(TARGET_IPHONE_SIMULATOR)
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
    {
        [[GBAEmulatorCore sharedCore] applyEmulationFilter:GBAEmulationFilterNone];
    }
    else
    {
        [[GBAEmulatorCore sharedCore] applyEmulationFilter:GBAEmulationFilterLinear];
    }
#endif
    
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
        [UIView animateWithDuration:0.4 animations:^{
            [self setBlurAlpha:0.0];
        } completion:^(BOOL finished) {
            [self removeBlur];
        }];
        
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
    
    [self dismissViewControllerAnimated:YES completion:completionBlock];
}

- (void)startEmulation
{
    [self stopEmulation]; // Stop previously running ROM
    
    self.pausedEmulation = NO;
    
    _romStartTime = CFAbsoluteTimeGetCurrent();
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] startEmulation];
#endif
}

- (void)stopEmulation
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] endEmulation];
#endif
    
    self.pausedEmulation = NO;
    
    [self resumeEmulation]; // In case the ROM never unpaused (just keep it here please)
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
    
    if (self.rom && !self.preventSavingROMSaveData)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] writeSaveFileForCurrentROMToDisk];
#endif
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] pauseEmulation];
#endif
}

- (void)resumeEmulation
{
    self.pausedEmulation = NO;
    self.stayPaused = NO;
    
    if (self.rom == nil)
    {
        return;
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] resumeEmulation];
    [[GBAEmulatorCore sharedCore] pressButtons:self.sustainedButtonSet];
#endif
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
        
        if (![self.rom isEvent])
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
    
    [self pauseEmulation];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            if (self.blurringContents)
            {
                [self refreshLayout];
            }
            else
            {
                [self blurWithInitialAlpha:0.0];
                
                [UIView animateWithDuration:0.3 animations:^{
                    [self setBlurAlpha:1.0];
                }];
            }
        }
        
        GBASyncingDetailViewController *syncingDetailViewController = [[GBASyncingDetailViewController alloc] initWithROM:self.rom];
        syncingDetailViewController.delegate = self;
        syncingDetailViewController.showDoneButton = YES;
        
        UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(syncingDetailViewController);
        
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
        
        while (presentingViewController.presentedViewController)
        {
            presentingViewController = presentingViewController.presentedViewController;
        }
        
        [presentingViewController presentViewController:navigationController animated:YES completion:NULL];
        
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
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] updateCheats];
#endif
}

- (void)syncingDetailViewControllerWillDismiss:(GBASyncingDetailViewController *)syncingDetailViewController
{
    UIViewController *presentedViewController = self.presentedViewController;
    if ([presentedViewController isKindOfClass:[UINavigationController class]])
    {
        presentedViewController = [[(UINavigationController *)presentedViewController viewControllers] firstObject];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        // Only hide status bar if the syncingDetailViewController was the modal view controller. If it isn't, the status bar should stay
        if (presentedViewController == syncingDetailViewController)
        {
            [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
        }
        
        // Used primarily to update the blurring, but can't help to update everything
        [self refreshLayout];
    }
    
    self.preventSavingROMSaveData = NO;

    if (presentedViewController == syncingDetailViewController)
    {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            if (![(GBASplitViewController *)self.splitViewController romTableViewControllerIsVisible])
            {
                [UIView animateWithDuration:0.3 animations:^{
                    [self setBlurAlpha:0.0];
                } completion:^(BOOL finished) {
                    [self removeBlur];
                }];
                
                [self resumeEmulation];
            }
        }
        else
        {
            [self resumeEmulation];
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
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [imageView sizeToFit];
        imageView.center = self.emulatorScreen.center;
        imageView.contentMode = UIViewContentModeBottom;
        imageView.alpha = alpha;
        [self.view addSubview:imageView];
        imageView;
    });
    
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.blurredContentsImageView
                                                                  attribute:NSLayoutAttributeCenterX
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.view
                                                                  attribute:NSLayoutAttributeCenterX
                                                                 multiplier:1.0
                                                                   constant:0];
    [self.view addConstraint:constraint];
    
    constraint = [NSLayoutConstraint constraintWithItem:self.blurredContentsImageView
                                                    attribute:NSLayoutAttributeCenterY
                                                    relatedBy:NSLayoutRelationEqual
                                                       toItem:self.view
                                                    attribute:NSLayoutAttributeCenterY
                                                   multiplier:1.0
                                                     constant:0];
    [self.view addConstraint:constraint];
    
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
    // Can be modified if wanting to eventually blur separate parts of the view, so it extends outwards into the black (smoother)
    CGFloat edgeExtension = 0;
    
    CGSize viewSize = CGSizeZero;
    
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        viewSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    }
    else
    {
        viewSize = CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    }
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(viewSize.width + edgeExtension * 2,
                                                      viewSize.height + edgeExtension * 2),
                                           YES, 1.0);
    
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
    
    CGFloat controllerAlpha = 1.0f;
    
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:skinsKey][@"portrait"];
        GBAControllerSkin *controller = nil;
        UIImage *controllerSkin = nil;
        
        if (self.externalController)
        {
            controller = [GBAControllerSkin invisibleSkin];
            controllerSkin = nil;
        }
        else
        {
            controller = [GBAControllerSkin controllerSkinWithContentsOfFile:[self filepathForSkinIdentifier:name]];
            
            controllerSkin = [controller imageForOrientation:GBAControllerSkinOrientationPortrait];
            
            if (controllerSkin == nil)
            {
                controller = [GBAControllerSkin defaultControllerSkinForSkinType:skinType];
                
                NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:skinsKey] mutableCopy];
                skins[@"portrait"] = defaultSkinIdentifier;
                [[NSUserDefaults standardUserDefaults] setObject:skins forKey:skinsKey];
                
                controllerSkin = [controller imageForOrientation:GBAControllerSkinOrientationPortrait];
            }
        }
        
        BOOL translucent = [[controller dictionaryForOrientation:GBAControllerSkinOrientationPortrait][@"translucent"] boolValue];
        
        if (translucent)
        {
            controllerAlpha = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
        }
        
        CGSize screenContainerSize = CGSizeMake(viewSize.width, viewSize.height - controllerSkin.size.height);
        CGRect screenRect = [controller screenRectForOrientation:GBAControllerSkinOrientationPortrait];
        
        if (self.emulatorScreen.eaglView && ![self isAirplaying]) // As of iOS 7.0.3 crashes when attempting to draw the empty emulatorScreen
        {
            if (CGRectIsEmpty(screenRect) || self.externalController)
            {
                CGSize screenSize = [self screenSizeForContainerSize:viewSize];
                
                [self.emulatorScreen drawViewHierarchyInRect:CGRectMake(edgeExtension + (screenContainerSize.width - screenSize.width) / 2.0,
                                                                        edgeExtension + (screenContainerSize.height - screenSize.height) / 2.0,
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
            [controllerSkin drawInRect:CGRectMake(edgeExtension + (viewSize.width - controllerSkin.size.width) / 2.0f,
                                                  edgeExtension + screenContainerSize.height,
                                                  controllerSkin.size.width,
                                                  controllerSkin.size.height) blendMode:kCGBlendModeNormal alpha:controllerAlpha];
        }
    }
    else
    {
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:skinsKey][@"landscape"];
        GBAControllerSkin *controller = nil;
        UIImage *controllerSkin = nil;
        
        if (self.externalController)
        {
            controller = [GBAControllerSkin invisibleSkin];
            controllerSkin = nil;
        }
        else
        {
            controller = [GBAControllerSkin controllerSkinWithContentsOfFile:[self filepathForSkinIdentifier:name]];
            
            controllerSkin = [controller imageForOrientation:GBAControllerSkinOrientationLandscape];
            
            if (controllerSkin == nil)
            {
                controller = [GBAControllerSkin defaultControllerSkinForSkinType:skinType];
                
                NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:skinsKey] mutableCopy];
                skins[@"landscape"] = defaultSkinIdentifier;
                [[NSUserDefaults standardUserDefaults] setObject:skins forKey:skinsKey];
                
                controllerSkin = [controller imageForOrientation:GBAControllerSkinOrientationLandscape];
            }
        }
        
        BOOL translucent = [[controller dictionaryForOrientation:GBAControllerSkinOrientationLandscape][@"translucent"] boolValue];
        
        if (translucent)
        {
            controllerAlpha = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacityKey];
        }
        
        CGSize screenContainerSize = CGSizeMake(viewSize.width, viewSize.height);
        CGRect screenRect = [controller screenRectForOrientation:GBAControllerSkinOrientationLandscape];
        
        if (self.emulatorScreen.eaglView && ![self isAirplaying]) // As of iOS 7.0.3 crashes when attempting to draw the empty emulatorScreen
        {
            if (CGRectIsEmpty(screenRect) || self.externalController)
            {
                CGSize screenSize = [self screenSizeForContainerSize:viewSize];
                
                [self.emulatorScreen drawViewHierarchyInRect:CGRectMake(edgeExtension + (screenContainerSize.width - screenSize.width) / 2.0,
                                                                        edgeExtension + (screenContainerSize.height - screenSize.height) / 2.0,
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
            [controllerSkin drawInRect:CGRectMake(edgeExtension + (viewSize.width - controllerSkin.size.width) / 2.0f,
                                                  edgeExtension,
                                                  controllerSkin.size.width,
                                                  controllerSkin.size.height) blendMode:kCGBlendModeNormal alpha:controllerAlpha];
        }
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIColor *tintColor = [UIColor colorWithWhite:0.11 alpha:0.73];
    return [image applyBlurWithRadius:10 tintColor:tintColor saturationDeltaFactor:1.8 maskImage:nil];
}

#pragma mark - Getters/Setters

- (void)setRom:(GBAROM *)rom
{
    _rom = rom;
    
    self.cachedSaveData = [[NSData alloc] initWithContentsOfFile:rom.saveFileFilepath];
    
    // Changing ROM should be done on main thread
    rst_dispatch_sync_on_main_thread(^{
        
        [self refreshLayout]; // Must go before resumeEmulation
        
        if (_rom) // If there was a previous ROM make sure to unpause it!
        {
            [self resumeEmulation];
        }
        
        [self stopFastForwarding];
        
        NSSet *sustainedButtons = [self.sustainedButtonSet copy];
        self.sustainedButtonSet = nil;
        
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] releaseButtons:sustainedButtons];
        [[GBAEmulatorCore sharedCore] setRom:self.rom];
#endif
        
        if (rom)
        {
            [self startEmulation];
        }
        else
        {
            [self stopEmulation];
            
            self.emulatorScreen.eaglView = nil;
            
            [self refreshLayout];
        }
        
        // [self.controllerView showButtonRects];
    });
}


- (BOOL)isAirplaying
{
    return (self.airplayWindow != nil);
}




@end











