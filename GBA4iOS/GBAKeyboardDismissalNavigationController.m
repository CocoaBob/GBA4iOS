//
//  GBAKeyboardDismissalNavigationController.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/18/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAKeyboardDismissalNavigationController.h"

@interface GBAKeyboardDismissalNavigationController ()

@end

@implementation GBAKeyboardDismissalNavigationController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Why is this not a property, I had to make a UINavigationController subclass JUST to return NO.

- (BOOL)disablesAutomaticKeyboardDismissal
{
    return NO;
}

@end
