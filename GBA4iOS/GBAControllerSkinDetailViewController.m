//
//  GBAControllerSkinDetailViewController.m
//  GBA4iOS
//
//  Created by Yvette Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDetailViewController.h"
#import "UIScreen+Widescreen.h"
#import "GBAController.h"
#import "GBASettingsViewController.h"
#import "GBAControllerSkinPreviewCell.h"
#import "GBAControllerSkinSelectionViewController.h"

@interface GBAControllerSkinDetailViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *portraitControllerSkinImageView;
@property (weak, nonatomic) IBOutlet UIImageView *landscapeControllerSkinImageView;

@end

@implementation GBAControllerSkinDetailViewController

- (id)init
{
    NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"GBAResources" ofType:@"bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:resourceBundle];
    self = [storyboard instantiateViewControllerWithIdentifier:@"controllerSkinsDetailViewController"];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([[UIScreen mainScreen] isWidescreen])
    {
        self.tableView.rowHeight = 190;
    }
    else
    {
        self.tableView.rowHeight = 150;
    }
    
    self.clearsSelectionOnViewWillAppear = YES;
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
            self.title = NSLocalizedString(@"GBA Controller Skins", @"");
            break;
            
        case GBAControllerSkinTypeGBC:
            self.title = NSLocalizedString(@"GBC Controller Skins", @"");
            break;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
}

- (NSString *)filepathForSkinName:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *skinsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Skins"];
    
    NSString *controllerType = nil;
    
    switch (self.controllerSkinType) {
        case GBAControllerSkinTypeGBA:
            controllerType = @"GBA";
            break;
            
        case GBAControllerSkinTypeGBC:
            controllerType = @"GBC";
            break;
    }
    
    NSString *controllerTypeDirectory = [skinsDirectory stringByAppendingPathComponent:controllerType];
    NSString *filepath = [controllerTypeDirectory stringByAppendingPathComponent:name];
    
    return filepath;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAControllerSkinPreviewCell *cell = (GBAControllerSkinPreviewCell *)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    NSDictionary *skinDictionary = nil;
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
            skinDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey];
            
            break;
            
        case GBAControllerSkinTypeGBC:
            skinDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBCSkinsKey];
            break;
    }
    
    NSString *portraitSkin = skinDictionary[@"portrait"];
    NSString *landscapeSkin = skinDictionary[@"landscape"];
    
    if (indexPath.section == 0)
    {
        GBAController *portraitController = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:portraitSkin]];
        cell.controller = portraitController;
        cell.orientation = GBAControllerOrientationPortrait;
    }
    else
    {
        GBAController *landscapeController = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:landscapeSkin]];
        cell.controller = landscapeController;
        cell.orientation = GBAControllerOrientationLandscape;
    }
    
    [cell update];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAControllerSkinSelectionViewController *controllerSkinSelectionViewController = [[GBAControllerSkinSelectionViewController alloc] init];
    controllerSkinSelectionViewController.controllerSkinType = self.controllerSkinType;
    
    if (indexPath.section == 0)
    {
        controllerSkinSelectionViewController.controllerOrientation = GBAControllerOrientationPortrait;
    }
    else
    {
        controllerSkinSelectionViewController.controllerOrientation = GBAControllerOrientationLandscape;
    }
    
    [self.navigationController pushViewController:controllerSkinSelectionViewController animated:YES];
}

@end
