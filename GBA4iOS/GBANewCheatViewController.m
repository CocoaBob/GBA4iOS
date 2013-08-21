//
//  GBANewCheatViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBANewCheatViewController.h"

@interface GBANewCheatViewController ()

- (IBAction)saveCheat:(UIBarButtonItem *)sender;

@end

@implementation GBANewCheatViewController

- (id)init
{
    NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"GBAResources" ofType:@"bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:resourceBundle];
    
    
    self = [storyboard instantiateViewControllerWithIdentifier:@"newCheatViewController"];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)saveCheat:(id)sender {
    GBACheat *cheat = [[GBACheat alloc] initWithName:@"Walk Through Walls" codes:@[@"C84AB3C0F5984A15", @"8E883EFF92E9660D"]];
    
    if ([self.delegate respondsToSelector:@selector(newCheatViewController:didSaveCheat:)])
    {
        [self.delegate newCheatViewController:self didSaveCheat:cheat];
    }
}

@end
