//
//  GBAEmulationViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulationViewController.h"
#import "GBAEmulatorCore.h"
#import "EAGLView.h"

// Emulator Includes
#include <util/time/sys.hh>
#include <base/Base.hh>
#include <base/iphone/private.hh>

#ifdef CONFIG_INPUT
#include <input/Input.hh>
#endif

@interface GBAEmulationViewController ()

@property (strong, nonatomic) EAGLView *eaglView;
@property (strong, nonatomic) GBAEmulatorCore *emulatorCore;

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (id)initWithROMFilepath:(NSString *)romFilepath
{
    self = [super init];
    if (self)
    {
        _romFilepath = [romFilepath copy];
        _eaglView = [[EAGLView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _eaglView.backgroundColor = [UIColor redColor];
        
        _emulatorCore = [[GBAEmulatorCore alloc] initWithEAGLView:_eaglView];
        
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    [self.view addSubview:self.eaglView];
    [self startEmulation];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (![self.view respondsToSelector:@selector(setTintColor:)])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    }
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

#pragma mark - Emulation

- (void)startEmulation
{
    doOrExit(logger_init());
	TimeMach::setTimebase();
    
#ifdef CONFIG_INPUT
	doOrExit(Input::init());
#endif
	
#ifdef CONFIG_AUDIO
	Audio::initSession();
#endif
    
    Base::grayColorSpace = CGColorSpaceCreateDeviceGray();
	Base::rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    [self.emulatorCore start];
}

@end
