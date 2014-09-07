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

#import <RSTWebViewController.h>

#import "UIAlertView+RSTAdditions.h"
#import "UITableViewController+ControllerSkins.h"

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
        
        
        UIUserInterfaceIdiom userInterfaceIdiom = [[UIDevice currentDevice] userInterfaceIdiom];
        GBAControllerSkinDeviceType deviceType = GBAControllerSkinDeviceTypeiPhone;
        
        if (userInterfaceIdiom == UIUserInterfaceIdiomPad)
        {
            deviceType = GBAControllerSkinDeviceTypeiPad;
        }
        else
        {
            deviceType = GBAControllerSkinDeviceTypeiPhone;
        }

        self.title = controllerSkinGroup.name;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:[GBAAsynchronousRemoteTableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"HeaderFooterViewIdentifier"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    GBAControllerSkin *skin = [self.controllerSkinGroup.skins firstObject];
    [self updateRowHeightsForDisplayingControllerSkinsWithType:skin.type];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Download Skin -

- (void)downloadControllerSkin:(GBAControllerSkin *)controllerSkin
{
    [self.downloadController downloadRemoteControllerSkin:controllerSkin completion:^(NSURL *fileURL, NSError *error) {
        
        if (error)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithError:error];
            [alert show];
            
            return;
        }
        
        [GBAControllerSkin extractSkinAtPathToSkinsDirectory:[fileURL path]];
        
    }];
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

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return [super tableView:tableView viewForFooterInSection:section];
    }
    
    static NSString *HeaderFooterViewIdentifier = @"HeaderFooterViewIdentifier";
    
    UIView *footerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:HeaderFooterViewIdentifier];
    
    if ([footerView gestureRecognizers] == 0)
    {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapSkinDesigner:)];
        [footerView addGestureRecognizer:tapGestureRecognizer];
    }
    
    footerView.tag = section;
    
    return footerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

#pragma mark - UITableViewDelegate -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAControllerSkin *skin = self.controllerSkinGroup.skins[indexPath.section - 1];
    
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to download “%@” skin?", @""), skin.name];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Download", @""), nil];
    [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            return;
        }
        
        [self downloadControllerSkin:skin];
    }];
    
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - Skin Designers -

- (void)didTapSkinDesigner:(UITapGestureRecognizer *)tapGestureRecognizer
{
    GBAControllerSkin *skin = self.controllerSkinGroup.skins[tapGestureRecognizer.view.tag - 1];
    
    if (skin.designerURL == nil)
    {
        return;
    }
    
    RSTWebViewController *webViewController = [[RSTWebViewController alloc] initWithURL:skin.designerURL];
    [self.navigationController pushViewController:webViewController animated:YES];
}

@end
