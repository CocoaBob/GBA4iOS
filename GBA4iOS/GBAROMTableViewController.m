//
//  GBAROMTableViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROMTableViewController.h"

typedef NS_ENUM(NSInteger, GBAROMType) {
    GBAROMTypeAll,
    GBAROMTypeGBA,
    GBAROMTypeGBC,
};

@interface GBAROMTableViewController ()

@property (assign, nonatomic) GBAROMType romType;
@property (weak, nonatomic) IBOutlet UISegmentedControl *romTypeSegmentedControl;

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
    
    GBAROMType romType = [[NSUserDefaults standardUserDefaults] integerForKey:@"romType"];
    self.romType = romType;
    
    // iOS 6 UI
    self.romTypeSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    self.navigationController.navigationBar.tintColor = [UIColor purpleColor];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - RSTFileBrowserViewController Subclass

- (NSString *)visibleFileExtensionForIndexPath:(NSIndexPath *)indexPath
{
    NSString *extension = [super visibleFileExtensionForIndexPath:indexPath];
    
    if ([[extension uppercaseString] isEqualToString:@"GB"])
    {
        extension = @"GBC";
    }
    
    return [extension uppercaseString];
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *filepath = [self filepathForIndexPath:indexPath];
}

#pragma mark - IBActions

- (IBAction)switchROMTypes:(UISegmentedControl *)segmentedControl
{
    GBAROMType romType = segmentedControl.selectedSegmentIndex;
    self.romType = romType;
}


#pragma mark - Getters/Setters

- (void)setRomType:(GBAROMType)romType
{
    self.romTypeSegmentedControl.selectedSegmentIndex = romType;
    [[NSUserDefaults standardUserDefaults] setInteger:romType forKey:@"romType"];
    
    switch (romType) {
        case GBAROMTypeAll:
            self.supportedFileExtensions = @[@"gba", @"gb", @"gbc"];
            break;
            
        case GBAROMTypeGBA:
            self.supportedFileExtensions = @[@"gba"];
            break;
            
        case GBAROMTypeGBC:
            self.supportedFileExtensions = @[@"gb", @"gbc"];
            break;
    }
    
    _romType = romType;
}




@end
