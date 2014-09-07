//
//  GBAControllerSkinGroupViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinGroupViewController.h"
#import "GBAControllerSkin.h"
#import "GBAAsynchronousRemoteTableViewCell.h"
#import "GBAControllerSkinGroup.h"
#import "GBAControllerSkinDownloadController.h"

#import "UIAlertView+RSTAdditions.h"

@interface GBAControllerSkinGroupViewController ()

@property (strong, nonatomic) NSCache *imageCache;

@end

@implementation GBAControllerSkinGroupViewController

- (instancetype)initWithControllerSkinGroup:(GBAControllerSkinGroup *)controllerSkinGroup
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        _controllerSkinGroup = controllerSkinGroup;
        
        _imageCache = [[NSCache alloc] init];
        
        self.title = controllerSkinGroup.name;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGFloat rowHeight = 150;
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    if ([[UIScreen mainScreen] respondsToSelector:@selector(fixedCoordinateSpace)])
    {
        screenBounds = [[UIScreen mainScreen].fixedCoordinateSpace convertRect:[UIScreen mainScreen].bounds fromCoordinateSpace:[UIScreen mainScreen].coordinateSpace];
    }
    
    CGFloat landscapeAspectRatio = CGRectGetWidth(screenBounds) / CGRectGetHeight(screenBounds);
    self.tableView.rowHeight = CGRectGetWidth(self.view.bounds) * landscapeAspectRatio;
    
    [self.tableView registerClass:[GBAAsynchronousRemoteTableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.controllerSkinGroup.skins count] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 0;
    }
    
    GBAControllerSkin *skin = self.controllerSkinGroup.skins[section - 1];
    NSArray *imageURLs = [self.downloadController imageURLsForControllerSkin:skin];
    
    return [imageURLs count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return nil;
    }
    
    GBAControllerSkin *skin = self.controllerSkinGroup.skins[section - 1];
    return skin.name;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return self.controllerSkinGroup.blurb;
    }
    
    GBAControllerSkin *skin = self.controllerSkinGroup.skins[section - 1];
    
    return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"By", @""), skin.designerName];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAAsynchronousRemoteTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    GBAControllerSkin *skin = self.self.controllerSkinGroup.skins[indexPath.section - 1];
    cell.imageURL = [self.downloadController imageURLsForControllerSkin:skin][indexPath.row];
    cell.imageCache = self.imageCache;
    
    cell.separatorInset = UIEdgeInsetsZero;
    // Configure the cell...
    
    return cell;
}


@end
