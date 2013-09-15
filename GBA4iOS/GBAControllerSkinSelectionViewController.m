//
//  GBAControllerSkinSelectionViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinSelectionViewController.h"
#import "UIScreen+Widescreen.h"
#import "GBAAsynchronousImageTableViewCell.h"
#import "GBASettingsViewController.h"
#import "GBAControllerSkinDownloadViewController.h"

#import <SSZipArchive/minizip/SSZipArchive.h>

@interface GBAControllerSkinSelectionViewController () {
    BOOL _viewDidAppear;
}

@property (copy, nonatomic) NSArray *filteredArray;
@property (strong, nonatomic) NSCache *imageCache;

@end

@implementation GBAControllerSkinSelectionViewController

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
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
            self.title = NSLocalizedString(@"GBA Controller Skins", @"");
            break;
            
        case GBAControllerSkinTypeGBC:
            self.title = NSLocalizedString(@"GBC Controller Skins", @"");
            break;
    }
    
    self.clearsSelectionOnViewWillAppear = YES;
    [self.tableView registerClass:[GBAAsynchronousImageTableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(downloadSkins:)];
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refreshControllerSkins];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _viewDidAppear = YES;
    
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Download Skins

- (void)downloadSkins:(UIBarButtonItem *)sender
{
    GBAControllerSkinDownloadViewController *controllerSkinDownloadViewController = [[GBAControllerSkinDownloadViewController alloc] init];
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(controllerSkinDownloadViewController) animated:YES completion:nil];
}

#pragma mark - Import Controller Skins

- (void)refreshControllerSkins
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    BOOL importedSkin = NO;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
        
    for (NSString *file in contents)
    {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"gbaskin"])
        {
            NSString *filepath = [documentsDirectory stringByAppendingPathComponent:file];
            [self importControllerSkinFromPath:filepath];
            importedSkin = YES;
        }
        
    }
    
    if (importedSkin)
    {
        self.filteredArray = nil;
        [self.tableView reloadData];
    }
}

- (void)importControllerSkinFromPath:(NSString *)filepath
{
    NSString *destinationFilename = [[filepath lastPathComponent] stringByDeletingPathExtension];
    NSString *destinationPath = [self skinsDirectory];
    
    NSError *error = nil;
    
    [SSZipArchive unzipFileAtPath:filepath toDestination:destinationPath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([[fileManager contentsOfDirectoryAtPath:[destinationPath stringByAppendingPathComponent:destinationFilename] error:nil] count] == 0)
    {
        DLog(@"Not finished yet");
        // Unzipped before it was done copying over
        return;
    }
    
    [fileManager removeItemAtPath:[destinationPath stringByAppendingPathComponent:@"__MACOSX"] error:nil];
    [fileManager removeItemAtPath:filepath error:nil];
    
    if (error)
    {
        ELog(error);
    }
}

#pragma mark - Helper Methods

- (NSString *)skinsDirectory
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
    
    return controllerTypeDirectory;
}

- (NSString *)keyForControllerOrientation:(GBAControllerOrientation)orientation
{
    NSString *key = nil;
    switch (orientation) {
        case GBAControllerOrientationPortrait:
            key = @"portrait";
            break;
            
        case GBAControllerOrientationLandscape:
            key = @"landscape";
            break;
    }
    
    return key;
}

#pragma mark - Getters/Setters

- (NSArray *)filteredArray
{
    if (_filteredArray == nil)
    {
        NSMutableArray *filteredArray = [NSMutableArray array];
        NSString *skinsDirectoryPath = [self skinsDirectory];
        
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:skinsDirectoryPath error:nil];
        
        for (NSString *name in contents)
        {
            @autoreleasepool
            {
                GBAController *controller = [GBAController controllerWithContentsOfFile:[skinsDirectoryPath stringByAppendingPathComponent:name]];
                
                if (controller.supportedOrientations & self.controllerOrientation)
                {
                    if ([name isEqualToString:@"Default"])
                    {
                        [filteredArray insertObject:controller atIndex:0];
                    }
                    else
                    {
                        [filteredArray addObject:controller];
                    }
                }
            }
        }
        
        _filteredArray = [filteredArray copy];
    }
    
    return _filteredArray;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [self.filteredArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    GBAController *controller = self.filteredArray[section];
    return controller.name;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    GBAAsynchronousImageTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    GBAController *controller = self.filteredArray[indexPath.section];
    
    if (_viewDidAppear)
    {
        cell.loadSynchronously = NO;
    }
    else
    {
        cell.loadSynchronously = YES;
    }
    
    cell.imageCache = self.imageCache;
    
    cell.image = [controller imageForOrientation:self.controllerOrientation];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAController *controller = self.filteredArray[indexPath.section];
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
        {
            NSMutableDictionary *skinDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey] mutableCopy];
            [skinDictionary setObject:controller.name forKey:[self keyForControllerOrientation:self.controllerOrientation]];
            [[NSUserDefaults standardUserDefaults] setObject:skinDictionary forKey:GBASettingsGBASkinsKey];
            
            break;
        }
            
            
        case GBAControllerSkinTypeGBC:
        {
            NSMutableDictionary *skinDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBCSkinsKey] mutableCopy];
            [skinDictionary setObject:controller.name forKey:[self keyForControllerOrientation:self.controllerOrientation]];
            [[NSUserDefaults standardUserDefaults] setObject:skinDictionary forKey:GBASettingsGBCSkinsKey];
            
            break;
        }
            
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return NO;
    }
    
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        GBAController *controller = self.filteredArray[indexPath.section];
        
        [[NSFileManager defaultManager] removeItemAtPath:controller.filepath error:nil];
        self.filteredArray = nil;
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end
