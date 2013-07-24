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

@interface GBAEmulationViewController ()

@property (weak, nonatomic) EAGLView *eaglView;
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
        
        _emulatorCore = [[GBAEmulatorCore alloc] initWithROMFilepath:_romFilepath];
        _eaglView = _emulatorCore.eaglView;
                
        NSLog(@"%@", romFilepath);
        
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

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Emulation

- (void)startEmulation
{
    [self.emulatorCore start];
}

@end
