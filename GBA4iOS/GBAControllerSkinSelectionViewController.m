//
//  GBAControllerSkinSelectionViewController.m
//  GBA4iOS
//
//  Created by Yvette Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinSelectionViewController.h"
#import "UIScreen+Widescreen.h"
#import "GBAControllerSkinPreviewCell.h"
#import "GBASettingsViewController.h"

@interface GBAControllerSkinSelectionViewController () {
    BOOL _viewDidAppear;
}

@property (copy, nonatomic) NSArray *filteredArray;

@end

@implementation GBAControllerSkinSelectionViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
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
    [self.tableView registerClass:[GBAControllerSkinPreviewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)viewDidAppear:(BOOL)animated
{
    _viewDidAppear = YES;
    [super viewDidAppear:animated];
    
    // Load asynchronously so scrolling doesn't stutter
    for (GBAControllerSkinPreviewCell *cell in [self.tableView visibleCells])
    {
        cell.loadAsynchronously = YES;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
                    [filteredArray addObject:controller];
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
    GBAControllerSkinPreviewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    GBAController *controller = self.filteredArray[indexPath.section];
    cell.controller = controller;
    cell.orientation = self.controllerOrientation;
    
    if (_viewDidAppear)
    {
        cell.loadAsynchronously = YES;
    }
    
    [(GBAControllerSkinPreviewCell *)cell update];
        
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

@end
