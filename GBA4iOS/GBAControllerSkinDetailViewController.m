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
#import "GBAAsynchronousImageTableViewCell.h"
#import "GBAControllerSkinSelectionViewController.h"

@interface GBAControllerSkinDetailViewController () {
    BOOL _viewDidAppear;
}

@property (weak, nonatomic) IBOutlet UIImageView *portraitControllerSkinImageView;
@property (weak, nonatomic) IBOutlet UIImageView *landscapeControllerSkinImageView;

@end

@implementation GBAControllerSkinDetailViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
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
    
    [self.tableView registerClass:[GBAAsynchronousImageTableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    self.clearsSelectionOnViewWillAppear = YES;
    
    self.title = NSLocalizedString(@"Current Skins", @"");
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    _viewDidAppear = YES;
    [super viewDidAppear:animated];
    
    // Load asynchronously so scrolling doesn't stutter
    for (GBAAsynchronousImageTableViewCell *cell in [self.tableView visibleCells])
    {
        cell.loadSynchronously = NO;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    _viewDidAppear = NO;
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"Portrait", @"");
    }
    else if (section == 1)
    {
        return NSLocalizedString(@"Landscape", @"");
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAAsynchronousImageTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
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
    
    if (_viewDidAppear)
    {
        cell.loadSynchronously = NO;
    }
    else
    {
        cell.loadSynchronously = YES;
    }
    
    if (indexPath.section == 0)
    {
        GBAController *portraitController = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:portraitSkin]];
        cell.image = [portraitController imageForOrientation:GBAControllerOrientationPortrait];
    }
    else
    {
        GBAController *landscapeController = [GBAController controllerWithContentsOfFile:[self filepathForSkinName:landscapeSkin]];
        cell.image = [landscapeController imageForOrientation:GBAControllerOrientationLandscape];
    }
    
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
