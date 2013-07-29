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

@interface GBAEmulationViewController ()

@property (weak, nonatomic) IBOutlet GBAEmulatorScreen *emulatorScreen;
@property (strong, nonatomic) IBOutlet GBAController *controller;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *portraitBottomLayoutConstraint;

#if !(TARGET_IPHONE_SIMULATOR)
@property (strong, nonatomic) GBAEmulatorCore *emulatorCore;
#endif

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#if !(TARGET_IPHONE_SIMULATOR)
    self.emulatorScreen.backgroundColor = [UIColor blackColor]; // It's set to blue in the storyboard for easier visual debugging
#endif
    
    self.controller.skinFilepath = self.skinFilepath;
    [self.controller addTarget:self action:@selector(selectedControllerButtonsDidChange:) forControlEvents:UIControlEventValueChanged];
    
    [self.controller showButtonRects];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (![self.view respondsToSelector:@selector(setTintColor:)])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
#if !(TARGET_IPHONE_SIMULATOR)
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        self.emulatorCore = [[GBAEmulatorCore alloc] initWithROMFilepath:_romFilepath];
        self.emulatorScreen.eaglView = _emulatorCore.eaglView;
        
        [self startEmulation];
        
    });
#endif
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (![self.view respondsToSelector:@selector(setTintColor:)])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
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

#pragma mark Controls

- (void)selectedControllerButtonsDidChange:(GBAController *)controller
{
    [self.emulatorCore setSelectedButtons:controller.pressedButtons];
}

/*- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
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
}*/

#define ROTATION_SHAPSHOT_TAG 13

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if ([self.view respondsToSelector:@selector(snapshotView)] && (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) != UIInterfaceOrientationIsPortrait(toInterfaceOrientation)))
    {
        UIView *snapshotView = [self.view snapshotView];
        snapshotView.transform = self.view.transform;
        snapshotView.frame = self.view.frame;
        snapshotView.tag = ROTATION_SHAPSHOT_TAG;
        
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        [window addSubview:snapshotView];
        
        self.view.alpha = 0.0;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if ([self.view respondsToSelector:@selector(snapshotView)])
    {
        UIView *snapshotView = [[[UIApplication sharedApplication] keyWindow] viewWithTag:ROTATION_SHAPSHOT_TAG];
        snapshotView.alpha = 0.0;
        self.view.alpha = 1.0;
    }
    
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if ([self.view respondsToSelector:@selector(snapshotView)])
    {
        UIView *snapshotView = [[[UIApplication sharedApplication] keyWindow] viewWithTag:ROTATION_SHAPSHOT_TAG];
        [snapshotView removeFromSuperview];
    }
}

- (void)viewWillLayoutSubviews
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        if ([[self.view constraints] containsObject:self.portraitBottomLayoutConstraint] == NO)
        {
            [self.view addConstraint:self.portraitBottomLayoutConstraint];
        }
        
        self.controller.orientation = GBAControllerOrientationPortrait;
        self.controller.alpha = 1.0f;
    }
    else
    {
        if ([[self.view constraints] containsObject:self.portraitBottomLayoutConstraint])
        {
            [self.view removeConstraint:self.portraitBottomLayoutConstraint];
        }
        
        self.controller.orientation = GBAControllerOrientationLandscape;
        self.controller.alpha = 0.5f;
    }
}

#pragma mark - Emulation

- (void)startEmulation
{
#if !(TARGET_IPHONE_SIMULATOR)
    [self.emulatorCore start];
#endif
}

@end
