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
#import "GBASplitViewController.h"

#if !(TARGET_IPHONE_SIMULATOR)
#import "GBAEmulatorCore.h"
#endif

#import <RSTActionSheet/UIActionSheet+RSTAdditions.h>
#include <sys/sysctl.h>

static GBAEmulationViewController *_emulationViewController;

@interface GBAEmulationViewController () <GBAControllerViewDelegate, UIViewControllerTransitioningDelegate, GBASaveStateViewControllerDelegate> {
    CFAbsoluteTime _romStartTime;
    CFAbsoluteTime _romPauseTime;
    BOOL _hasPerformedInitialLayout;
}

@property (weak, nonatomic) IBOutlet GBAEmulatorScreen *emulatorScreen;
@property (strong, nonatomic) IBOutlet GBAControllerView *controllerView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *portraitBottomLayoutConstraint;
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
@property (strong, nonatomic) UIImageView *blurredContentsImageView;

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (instancetype)initWithROM:(GBAROM *)rom
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"emulationViewController"];
    if (self)
    {
        _emulationViewController = self;
        InstallUncaughtExceptionHandler();
        
        [self setRom:rom];
        
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidConnect:) name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLink:)];
	[self.displayLink setFrameInterval:1];
	[self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    
    [self updateSettings:nil];
}

- (void)performInitialLayout
{
    [self.view layoutIfNeeded];
    
    [self updateControllerSkinForInterfaceOrientation:self.interfaceOrientation];
    
    if (self.airplayWindow == nil)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.view.bounds.size] screen:[UIScreen mainScreen]];
        [self.emulatorScreen invalidateIntrinsicContentSize];
#endif
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    self.emulatorScreen.eaglView = [[GBAEmulatorCore sharedCore] eaglView];
#endif
    
    if (self.rom)
    {        
        [self startEmulation];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [(GBASplitViewController *)self.splitViewController showROMTableViewControllerWithAnimation:NO];
        });
    }
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!_hasPerformedInitialLayout)
    {
        [self performInitialLayout];
        _hasPerformedInitialLayout = YES;
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    if (self.presentedViewController)
    {
        [self resumeEmulation];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [UIApplication sharedApplication].statusBarOrientation = UIInterfaceOrientationLandscapeLeft;
}

- (void)viewWillDisappear:(BOOL)animated
{
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

- (NSString *)filepathForSkinName:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *skinsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Skins"];
    
    NSString *controllerType = @"GBA";
    
    NSString *controllerTypeDirectory = [skinsDirectory stringByAppendingPathComponent:controllerType];
    NSString *filepath = [controllerTypeDirectory stringByAppendingPathComponent:name];
    
    return filepath;
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
        [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:screenBounds.size] screen:screen];
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
    [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:self.view.bounds.size screen:[UIScreen mainScreen]];
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

- (void)controllerView:(GBAControllerView *)controller didPressButtons:(NSSet *)buttons
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

- (void)controllerView:(GBAControllerView *)controller didReleaseButtons:(NSSet *)buttons
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

- (void)controllerViewDidPressMenuButton:(GBAControllerView *)controller
{
    _romPauseTime = CFAbsoluteTimeGetCurrent();
    
    [self pauseEmulation];
    
    UIActionSheet *actionSheet = nil;
    
    if ([self numberOfCPUCoresForCurrentDevice] == 1)
    {
        actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
                                                  delegate:nil
                                         cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                    destructiveButtonTitle:NSLocalizedString(@"Return To Menu", @"")
                                         otherButtonTitles:
                       NSLocalizedString(@"Save State", @""),
                       NSLocalizedString(@"Load State", @""),
                       NSLocalizedString(@"Cheat Codes", @""),
                       NSLocalizedString(@"Sustain Button", @""), nil];
    }
    else
    {
        actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Paused", @"")
                                                  delegate:nil
                                         cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                    destructiveButtonTitle:NSLocalizedString(@"Return To Menu", @"")
                                         otherButtonTitles:
                       NSLocalizedString(@"Fast Forward", @""),
                       NSLocalizedString(@"Save State", @""),
                       NSLocalizedString(@"Load State", @""),
                       NSLocalizedString(@"Cheat Codes", @""),
                       NSLocalizedString(@"Sustain Button", @""), nil];
    }
    
    void (^selectionHandler)(UIActionSheet *actionSheet, NSInteger buttonIndex) = ^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            [self returnToROMTableViewController];
        }
        else {
            if ([self numberOfCPUCoresForCurrentDevice] == 1)
            {
                // Compensate for lack of Fast Forward button
                buttonIndex = buttonIndex + 1;
            }
            
            if (buttonIndex == 1)
            {
                [self blurWithInitialAlpha:1.0f];
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
            else {
                [self resumeEmulation];
            }
        }
    };
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [actionSheet showInView:self.view selectionHandler:selectionHandler];
    }
    else
    {
        CGRect rect = [self.controllerView.controller rectForButtonRect:GBAControllerRectMenu orientation:self.controllerView.orientation];
        
        CGRect convertedRect = [self.view convertRect:rect fromView:self.controllerView];
        
        // Create a rect that will make the action sheet appear ABOVE the menu button, not to the right
        convertedRect.origin.x = 0;
        convertedRect.size.width = self.controllerView.bounds.size.width;
        
        [actionSheet showFromRect:convertedRect inView:self.view animated:YES selectionHandler:selectionHandler];
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
    NSString *filename = self.rom.name;
    
    GBASaveStateViewController *saveStateViewController = [[GBASaveStateViewController alloc] initWithSaveStateDirectory:[self saveStateDirectory] mode:mode];
    saveStateViewController.delegate = self;
    saveStateViewController.modalPresentationStyle = UIModalPresentationCustom;
    
    if ([saveStateViewController respondsToSelector:@selector(transitioningDelegate)])
    {
        saveStateViewController.transitioningDelegate = self;
    }
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(saveStateViewController) animated:YES completion:nil];
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
    
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    
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
    
    BOOL translucent = [[self.controllerView.controller dictionaryForOrientation:self.controllerView.orientation][@"translucent"] boolValue];
    
    if (translucent)
    {
        self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacity];
    }
    else
    {
        self.controllerView.skinOpacity = 1.0f;
    }
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

- (void)returnToROMTableViewController
{
    if ([self shouldAutosave])
    {
        [self updateAutosaveState];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
    }
    else
    {
        [(GBASplitViewController *)self.splitViewController showROMTableViewControllerWithAnimation:YES];
    }
}

#pragma mark - App Status

- (void)willResignActive:(NSNotification *)notification
{
    [self pauseEmulation];
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
}

- (void)willEnterForeground:(NSNotification *)notification
{
    // Check didBecomeActive:
}

#pragma mark - Layout

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
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
        UIView *blurredSnapshot = [self.blurredContentsImageView snapshotViewAfterScreenUpdates:NO];
        blurredSnapshot.frame = self.blurredContentsImageView.frame;
        blurredSnapshot.tag = BLURRED_SNAPSHOT_TAG;
        blurredSnapshot.alpha = 1.0;
        
        [self.view addSubview:blurredSnapshot];
        
        self.blurredContentsImageView.image = [self blurredViewImageForInterfaceOrientation:toInterfaceOrientation];
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
    
    if (self.airplayWindow == nil)
    {
#if !(TARGET_IPHONE_SIMULATOR)
        [[GBAEmulatorCore sharedCore] updateEAGLViewForSize:[self screenSizeForContainerSize:self.view.bounds.size] screen:[UIScreen mainScreen]];
        [self.emulatorScreen invalidateIntrinsicContentSize];
#else 
        
        if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
        {
            self.emulatorScreen.bounds = CGRectMake(0, 0, 320, 240);
        }
        else
        {
            self.emulatorScreen.bounds = CGRectMake(0, 0, 480, 320);
        }
        
#endif
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    UIView *controllerSnapshot = [self.view viewWithTag:CONTROLLER_SNAPSHOT_TAG];
    [controllerSnapshot removeFromSuperview];
    
    UIView *blurredSnapshot = [self.view viewWithTag:BLURRED_SNAPSHOT_TAG];
    [blurredSnapshot removeFromSuperview];
}

- (void)viewWillLayoutSubviews
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        if (![[self.view constraints] containsObject:self.portraitBottomLayoutConstraint])
        {
            [self.view addConstraint:self.portraitBottomLayoutConstraint];
        }
    }
    else
    {
        if ([[self.view constraints] containsObject:self.portraitBottomLayoutConstraint])
        {
            [self.view removeConstraint:self.portraitBottomLayoutConstraint];
        }
    }
}

- (void)updateControllerSkinForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey][@"portrait"];
        GBAController *controller = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:name]];
        
        self.controllerView.controller = controller;
        self.controllerView.orientation = GBAControllerOrientationPortrait;
        
        BOOL translucent = [[controller dictionaryForOrientation:GBAControllerOrientationPortrait][@"translucent"] boolValue];
        
        if (translucent)
        {
            self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacity];
        }
        else
        {
            self.controllerView.skinOpacity = 1.0f;
        }
        
    }
    else
    {
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey][@"landscape"];
        GBAController *controller = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:name]];
        self.controllerView.controller = controller;
        self.controllerView.orientation = GBAControllerOrientationLandscape;
        
        BOOL translucent = [[controller dictionaryForOrientation:GBAControllerOrientationLandscape][@"translucent"] boolValue];
        
        if (translucent)
        {
            self.controllerView.skinOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:GBASettingsControllerOpacity];
        }
        else
        {
            self.controllerView.skinOpacity = 1.0f;
        }
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
    [self stopEmulation]; // Stop previously running ROM
    
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
    
    [self resumeEmulation]; // In case the ROM never unpaused (just keep it here please)
}

- (void)pauseEmulation
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] pauseEmulation];
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
    self.blurredContentsImageView = ({
        UIImage *blurredImage = [self blurredViewImageForInterfaceOrientation:self.interfaceOrientation];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:blurredImage];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [imageView sizeToFit];
        imageView.center = self.emulatorScreen.center;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.alpha = alpha;
        [self.view addSubview:imageView];
        imageView;
    });
    
    self.controllerView.hidden = YES;
    
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

- (UIImage *)blurredViewImageForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
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
                                           YES, 0.0);
    
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey][@"portrait"];
        GBAController *controller = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:name]];
        UIImage *controllerSkin = [controller imageForOrientation:GBAControllerOrientationPortrait];
        
        CGSize screenContainerSize = CGSizeMake(viewSize.width, viewSize.height - controllerSkin.size.height);
        CGSize screenSize = [self screenSizeForContainerSize:viewSize];
        
        [self.emulatorScreen drawViewHierarchyInRect:CGRectMake(edgeExtension + (screenContainerSize.width - screenSize.width) / 2.0,
                                                                edgeExtension + (screenContainerSize.height - screenSize.height) / 2.0,
                                                                screenSize.width,
                                                                screenSize.height) afterScreenUpdates:NO];
        
        [controllerSkin drawInRect:CGRectMake(edgeExtension + (viewSize.width - controllerSkin.size.width) / 2.0f,
                                              edgeExtension + screenContainerSize.height,
                                              controllerSkin.size.width,
                                              controllerSkin.size.height)];
    }
    else
    {
        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey][@"landscape"];
        GBAController *controller = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:name]];
        UIImage *controllerSkin = [controller imageForOrientation:GBAControllerOrientationLandscape];
        
        CGSize screenContainerSize = CGSizeMake(viewSize.width, viewSize.height);
        CGSize screenSize = [self screenSizeForContainerSize:viewSize];
        
        [self.emulatorScreen drawViewHierarchyInRect:CGRectMake(edgeExtension + (screenContainerSize.width - screenSize.width) / 2.0,
                                                                     edgeExtension + (screenContainerSize.height - screenSize.height) / 2.0,
                                                                     screenSize.width,
                                                                     screenSize.height) afterScreenUpdates:NO];
        
        [controllerSkin drawInRect:CGRectMake(edgeExtension + (viewSize.width - controllerSkin.size.width) / 2.0f,
                                              edgeExtension,
                                              controllerSkin.size.width,
                                              controllerSkin.size.height)];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIColor *tintColor = [UIColor colorWithWhite:0.11 alpha:0.73];
    return [image applyBlurWithRadius:10 tintColor:tintColor saturationDeltaFactor:1.8 maskImage:nil];
}

#pragma mark - Getters/Setters

- (void)setRom:(GBAROM *)rom
{
    if (rom == nil)
    {
        return;
    }
    
    if (_rom) // If there was a previous ROM make sure to unpause it!
    {
        [self resumeEmulation];
    }
    
    // Put this after the resume because even if the ROM is the same, we need to resume the game since we paused it
    if ([_rom isEqual:rom])
    {
        return;
    }
    
    _rom = rom;
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] setRom:self.rom];
#endif
    
    if (_hasPerformedInitialLayout) // Has already appeared, so we can start the ROM!
    {
        [self startEmulation];
    }
    
}









@end











