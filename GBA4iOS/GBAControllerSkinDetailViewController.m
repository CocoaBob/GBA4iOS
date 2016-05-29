//
//  GBAControllerSkinDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDetailViewController.h"
#import "GBASettingsViewController.h"
#import "GBAAsynchronousLocalImageTableViewCell.h"
#import "GBAControllerSkinSelectionViewController.h"
#import "GBAControllerSkinDownloadViewController.h"

#import "UITableViewController+ControllerSkins.h"

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
    
    [self.tableView registerClass:[GBAAsynchronousLocalImageTableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    self.clearsSelectionOnViewWillAppear = YES;
    
    self.title = NSLocalizedString(@"Current Skins", @"");
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(downloadSkins:)];
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateRowHeightsForDisplayingControllerSkinsWithType:self.controllerSkinType];
    
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
    
    NSString *filepath = [skinsDirectory stringByAppendingPathComponent:identifier];
        
    return filepath;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Download Skins

- (void)downloadSkins:(UIBarButtonItem *)sender
{
    GBAControllerSkinDownloadViewController *downloadGroupsViewController = [[GBAControllerSkinDownloadViewController alloc] initWithControllerSkinType:self.controllerSkinType];
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(downloadGroupsViewController);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [self presentViewController:navigationController animated:YES completion:nil];
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
    NSString *defaultSkinIdentifier = nil;
    NSString *skinsKey = nil;
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
            skinDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey];
            defaultSkinIdentifier = [@"GBA/" stringByAppendingString:GBADefaultSkinIdentifier];
            skinsKey = GBASettingsGBASkinsKey;
            break;
            
        case GBAControllerSkinTypeGBC:
            skinDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBCSkinsKey];
            defaultSkinIdentifier = [@"GBC/" stringByAppendingString:GBADefaultSkinIdentifier];
            skinsKey = GBASettingsGBCSkinsKey;
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
        
        GBAControllerSkin *portraitController = [GBAControllerSkin controllerSkinWithContentsOfFile:[self filepathForSkinIdentifier:portraitSkin]];
                
        UIImage *image = [portraitController imageForOrientation:GBAControllerSkinOrientationPortrait];
        
        if (image == nil)
        {
            portraitController = [GBAControllerSkin defaultControllerSkinForSkinType:self.controllerSkinType];
            
            NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:skinsKey] mutableCopy];
            skins[@"portrait"] = defaultSkinIdentifier;
            [[NSUserDefaults standardUserDefaults] setObject:skins forKey:skinsKey];
            
            image = [portraitController imageForOrientation:GBAControllerSkinOrientationPortrait];
        }
        
        cell.image = image;
    }
    else
    {
        cell.cacheKey = @"Landscape";
        
        GBAControllerSkin *landscapeController = [GBAControllerSkin controllerSkinWithContentsOfFile:[self filepathForSkinIdentifier:landscapeSkin]];
        UIImage *image = [landscapeController imageForOrientation:GBAControllerSkinOrientationLandscape];
        
        if (image == nil)
        {
            landscapeController = [GBAControllerSkin defaultControllerSkinForSkinType:self.controllerSkinType];
            
            NSMutableDictionary *skins = [[[NSUserDefaults standardUserDefaults] objectForKey:skinsKey] mutableCopy];
            skins[@"landscape"] = defaultSkinIdentifier;
            [[NSUserDefaults standardUserDefaults] setObject:skins forKey:skinsKey];
            
            image = [landscapeController imageForOrientation:GBAControllerSkinOrientationLandscape];
        }
        
        cell.image = image;
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
        controllerSkinSelectionViewController.controllerOrientation = GBAControllerSkinOrientationPortrait;
    }
    else
    {
        controllerSkinSelectionViewController.controllerOrientation = GBAControllerSkinOrientationLandscape;
    }
    
    [self.navigationController pushViewController:controllerSkinSelectionViewController animated:YES];
}

@end
