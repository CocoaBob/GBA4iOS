//
//  GBAROMTableViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROMTableViewController.h"

@interface GBAROMTableViewController ()

@end

@implementation GBAROMTableViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        
        self.currentDirectory = documentsDirectory;
        self.supportedFileExtensions = @[@"gba", @"zip", @"gb", @"gbc"];
        self.showFileExtensions = YES;
        self.showFolders = NO;
        self.showSectionTitles = NO;
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

@end
