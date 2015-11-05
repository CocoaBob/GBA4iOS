//
//  GBAControllerSkinSelectionViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinSelectionViewController.h"
#import "GBAAsynchronousLocalImageTableViewCell.h"
#import "GBASettingsViewController.h"
#import "GBAControllerSkinDownloadViewController.h"
#import "GBAControllerSkin.h"

#import "UITableViewController+ControllerSkins.h"

#import "SSZipArchive.h"

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
    [self.tableView registerClass:[GBAAsynchronousLocalImageTableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateRowHeightsForDisplayingControllerSkinsWithType:self.controllerSkinType];
    
    [self refreshControllerSkins];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _viewDidAppear = YES;
    
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Import Controller Skins

- (void)refreshControllerSkins
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
        
    for (NSString *file in contents)
    {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"gbaskin"] || [[[file pathExtension] lowercaseString] isEqualToString:@"gbcskin"])
        {
            NSString *filepath = [documentsDirectory stringByAppendingPathComponent:file];
            [GBAControllerSkin extractSkinAtPathToSkinsDirectory:filepath];
            [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        }
    }
    
    // Refresh in case a new skin was downloaded
    self.filteredArray = nil;
    [self.imageCache removeAllObjects];
    [self.tableView reloadData];
}

#pragma mark - Helper Methods

- (NSString *)GBASkinsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *skinsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Skins"];
    
    NSString *controllerType = @"GBA";
    
    NSString *controllerTypeDirectory = [skinsDirectory stringByAppendingPathComponent:controllerType];
    
    return controllerTypeDirectory;
}

- (NSString *)GBCSkinsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *skinsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Skins"];
    
    NSString *controllerType = @"GBC";
    
    NSString *controllerTypeDirectory = [skinsDirectory stringByAppendingPathComponent:controllerType];
    
    return controllerTypeDirectory;
}

- (NSString *)keyForControllerOrientation:(GBAControllerSkinOrientation)orientation
{
    NSString *key = nil;
    switch (orientation) {
        case GBAControllerSkinOrientationPortrait:
            key = @"portrait";
            break;
            
        case GBAControllerSkinOrientationLandscape:
            key = @"landscape";
            break;
    }
    
    return key;
}

- (NSArray *)controllersFromDirectory:(NSString *)directory prioritizeDefaultSkin:(BOOL)prioritizeDefaultSkin
{
    NSMutableArray *array = [NSMutableArray array];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    
    for (NSString *identifier in contents)
    {
        @autoreleasepool
        {
            GBAControllerSkin *controller = [GBAControllerSkin controllerSkinWithContentsOfFile:[directory stringByAppendingPathComponent:identifier]];
            
            if ([controller imageForOrientation:self.controllerOrientation])
            {
                if ([identifier isEqualToString:GBADefaultSkinIdentifier] && prioritizeDefaultSkin)
                {
                    [array insertObject:controller atIndex:0];
                }
                else
                {
                    [array addObject:controller];
                }
            }
        }
    }
    
    return array;
}

#pragma mark - Getters/Setters

- (NSArray *)filteredArray
{
    if (_filteredArray == nil)
    {
        NSMutableArray *filteredArray = [NSMutableArray array];
        
        BOOL prioritizeDefaultSkin = YES;
        
        if (self.controllerSkinType == GBAControllerSkinTypeGBC)
        {
            [filteredArray addObjectsFromArray:[self controllersFromDirectory:[self GBCSkinsDirectory] prioritizeDefaultSkin:YES]];
            prioritizeDefaultSkin = NO;
        }
                
        // Both GBC and GBA games can use GBA skins
        [filteredArray addObjectsFromArray:[self controllersFromDirectory:[self GBASkinsDirectory] prioritizeDefaultSkin:prioritizeDefaultSkin]];
                
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
    GBAControllerSkin *controller = self.filteredArray[section];
    
    NSString *name = controller.name;
    
    // Change the name of the default skin of the other type so it's not confusing to the user
    if ([controller.identifier isEqualToString:GBADefaultSkinIdentifier] && controller.type != self.controllerSkinType)
    {
        switch (controller.type)
        {
            case GBAControllerSkinTypeGBA:
                name = @"GBA Default";
                break;
                
            case GBAControllerSkinTypeGBC:
                name = @"GBC Default";
                break;
        }
    }
    
    return name;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    GBAAsynchronousLocalImageTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    GBAControllerSkin *controller = self.filteredArray[indexPath.section];

    NSString *prefix = nil;
    
    switch (controller.type)
    {
        case GBAControllerSkinTypeGBA:
            prefix = @"GBA/";
            break;
            
        case GBAControllerSkinTypeGBC:
            prefix = @"GBC/";
            break;
    }
    
    cell.cacheKey = [prefix stringByAppendingString:controller.identifier];
    
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
    GBAControllerSkin *controller = self.filteredArray[indexPath.section];
    
    NSString *identifier = nil;
    
    switch (controller.type)
    {
        case GBAControllerSkinTypeGBA:
            identifier = [@"GBA/" stringByAppendingString:controller.identifier];
            break;
            
        case GBAControllerSkinTypeGBC:
            identifier = [@"GBC/" stringByAppendingString:controller.identifier];
            break;
    }
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
        {
            NSMutableDictionary *skinDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBASkinsKey] mutableCopy];
            [skinDictionary setObject:identifier forKey:[self keyForControllerOrientation:self.controllerOrientation]];
            [[NSUserDefaults standardUserDefaults] setObject:skinDictionary forKey:GBASettingsGBASkinsKey];
            
            break;
        }
            
            
        case GBAControllerSkinTypeGBC:
        {
            NSMutableDictionary *skinDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsGBCSkinsKey] mutableCopy];
            [skinDictionary setObject:identifier forKey:[self keyForControllerOrientation:self.controllerOrientation]];
            [[NSUserDefaults standardUserDefaults] setObject:skinDictionary forKey:GBASettingsGBCSkinsKey];
            
            break;
        }
            
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAControllerSkin *controller = self.filteredArray[indexPath.section];
    
    if ([controller.identifier isEqualToString:GBADefaultSkinIdentifier])
    {
        return NO;
    }
    
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        GBAControllerSkin *controller = self.filteredArray[indexPath.section];
        
        [[NSFileManager defaultManager] removeItemAtPath:controller.filepath error:nil];
        self.filteredArray = nil;
        
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end
