//
//  GBAControllerSkinDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDetailViewController.h"
#import "UIScreen+Widescreen.h"
#import "GBAController.h"
#import "GBASettingsViewController.h"
#import "GBAAsynchronousLocalImageTableViewCell.h"
#import "GBAControllerSkinSelectionViewController.h"

@interface GBAControllerSkinDetailViewController () {
    BOOL _viewDidAppear;
}

@property (weak, nonatomic) IBOutlet UIImageView *portraitControllerSkinImageView;
@property (weak, nonatomic) IBOutlet UIImageView *landscapeControllerSkinImageView;
@property (strong, nonatomic) NSCache *imageCache;

@end

@implementation GBAControllerSkinDetailViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        _imageCache = [[NSCache alloc] init];
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
    
    [self.tableView registerClass:[GBAAsynchronousLocalImageTableViewCell class] forCellReuseIdentifier:@"Cell"];
    
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
    for (GBAAsynchronousLocalImageTableViewCell *cell in [self.tableView visibleCells])
    {
        cell.loadSynchronously = NO;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    _viewDidAppear = NO;
    
    // If user picks a new skin, make sure the old one isn't displayed
    [self.imageCache removeAllObjects];
}

- (NSString *)filepathForSkinIdentifier:(NSString *)identifier
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
    NSString *filepath = [controllerTypeDirectory stringByAppendingPathComponent:identifier];
    
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
    GBAAsynchronousLocalImageTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.imageCache = self.imageCache;
    
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
        cell.cacheKey = @"Portrait";
        
        GBAController *portraitController = [GBAController controllerWithContentsOfFile:[self filepathForSkinIdentifier:portraitSkin]];
        
        if (portraitController == nil)
        {
            portraitController = [GBAController controllerWithContentsOfFile:[self filepathForSkinIdentifier:GBADefaultSkinIdentifier]];
            
            NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey] mutableCopy];
            skins[@"portrait"] = GBADefaultSkinIdentifier;
            [[NSUserDefaults standardUserDefaults] setObject:skins forKey:GBASettingsGBASkinsKey];
        }
        
        cell.image = [portraitController imageForOrientation:GBAControllerOrientationPortrait];
    }
    else
    {
        cell.cacheKey = @"Landscape";
        
        GBAController *landscapeController = [GBAController controllerWithContentsOfFile:[self filepathForSkinIdentifier:landscapeSkin]];
        
        if (landscapeController == nil)
        {
            landscapeController = [GBAController controllerWithContentsOfFile:[self filepathForSkinIdentifier:GBADefaultSkinIdentifier]];
            
            NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey] mutableCopy];
            skins[@"landscape"] = GBADefaultSkinIdentifier;
            [[NSUserDefaults standardUserDefaults] setObject:skins forKey:GBASettingsGBASkinsKey];
        }
        
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
