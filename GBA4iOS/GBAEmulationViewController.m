//
//  GBAEmulationViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulationViewController.h"

@interface GBAEmulationViewController ()

@end

@implementation GBAEmulationViewController

#pragma mark - UIViewController subclass

- (id)initWithROMFilepath:(NSString *)romFilepath
{
    self = [super init];
    if (self)
    {
        _romFilepath = [romFilepath copy];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
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
    
}

@end
