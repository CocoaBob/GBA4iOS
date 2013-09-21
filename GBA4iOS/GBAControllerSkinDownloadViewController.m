//
//  GBAControllerSkinDownloadViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/2/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDownloadViewController.h"
#import "UIScreen+Widescreen.h"
#import "GBAAsynchronousLocalImageTableViewCell.h"
#import "GBAController.h"

#define CONTROLLER_SKIN_DOWNLOAD_PLIST_URL [NSURL URLWithString:@"http://rileytestut.com/gba4ios/skins/root.plist"]

@interface GBAControllerSkinDownloadViewController ()

@property (copy, nonatomic) NSArray *skinsArray;
@property (strong, nonatomic) UIProgressView *downloadProgressView;
@property (strong, nonatomic) UIActivityIndicatorView *downloadingControllerSkinInfoActivityIndicatorView;
@property (strong, nonatomic) NSCache *imageCache;

@end

@implementation GBAControllerSkinDownloadViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        // Custom initialization
        _skinsArray = [NSArray arrayWithContentsOfFile:[self cachedControllerSkinInfoPath]];
        self.title = NSLocalizedString(@"Download Skins", @"");
        
        _imageCache = [[NSCache alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self downloadControllerSkinInfo];
    });
    
    self.downloadProgressView = ({
        UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        progressView.frame = CGRectMake(0,
                                        CGRectGetHeight(self.navigationController.navigationBar.bounds) - CGRectGetHeight(progressView.bounds),
                                        CGRectGetWidth(self.navigationController.navigationBar.bounds),
                                        CGRectGetHeight(progressView.bounds));
        progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        progressView.trackTintColor = [UIColor clearColor];
        progressView.progress = 0.0;
        progressView.alpha = 0.0;
        [self.navigationController.navigationBar addSubview:progressView];
        progressView;
    });
    
    self.downloadingControllerSkinInfoActivityIndicatorView = ({
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityIndicatorView.hidesWhenStopped = YES;
        [activityIndicatorView startAnimating];
        activityIndicatorView;
    });
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    UIBarButtonItem *activityIndicatorViewButton = [[UIBarButtonItem alloc] initWithCustomView:self.downloadingControllerSkinInfoActivityIndicatorView];
    self.navigationItem.leftBarButtonItem = activityIndicatorViewButton;
    
    if ([[UIScreen mainScreen] isWidescreen])
    {
        self.tableView.rowHeight = 190;
    }
    else
    {
        self.tableView.rowHeight = 150;
    }
    
    [self.tableView registerClass:[GBAAsynchronousLocalImageTableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Downloading

- (void)downloadControllerSkinInfo
{
    NSArray *array = [NSArray arrayWithContentsOfURL:CONTROLLER_SKIN_DOWNLOAD_PLIST_URL];
    NSArray *previousSkinsArray = [self.skinsArray copy];
    
    if (array == nil)
    {
        return;
    }
    
    self.skinsArray = array;
    [self.skinsArray writeToFile:[self cachedControllerSkinInfoPath] atomically:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.downloadingControllerSkinInfoActivityIndicatorView stopAnimating];
        
        if ([self.skinsArray isEqualToArray:previousSkinsArray])
        {
            // Just in case
            [self.tableView reloadData];
        }
        else
        {
            // Animated reloadData FTW
            [UIView transitionWithView:self.tableView
                              duration:0.3f
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^(void) {
                                [self.tableView reloadData];
                            } completion:NULL];
        }
        
    });
}

#pragma mark - Dismissal

- (void)dismiss:(UIBarButtonItem *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.skinsArray count] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 0;
    }
    
    NSDictionary *dictionary = [self dictionaryForSection:section];
    
    NSInteger supportedOrientations = 0;
    
    if (dictionary[@"portraitAssets"])
    {
        supportedOrientations++;
    }
    
    if (dictionary[@"landscapeAssets"])
    {
        supportedOrientations++;
    }
    
    return supportedOrientations;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return nil;
    }
    
    NSDictionary *dictionary = [self dictionaryForSection:section];
    
    return dictionary[@"name"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"You can import other .gbaskin or .gbcskin files via iTunes, or by downloading them in Safari and opening in GBA4iOS.", @"");
    }
    
    NSDictionary *dictionary = [self dictionaryForSection:section];
    
    return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"By", @""), dictionary[@"designer"]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    GBAAsynchronousLocalImageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:indexPath.section];
    
    NSDictionary *dictionary = [self dictionaryForSection:indexPath.section];
    NSDictionary *portraitDictionary = dictionary[@"portraitAssets"];
    NSDictionary *landscapeDictionary = dictionary[@"landscapeAssets"];
    
    cell.imageCache = self.imageCache;
    
    if (numberOfRows == 1)
    {
        if (portraitDictionary)
        {
            cell.imageURL = [NSURL URLWithString:[self imageAddressForDictionary:portraitDictionary]];
        }
        else
        {
            cell.imageURL = [NSURL URLWithString:[self imageAddressForDictionary:landscapeDictionary]];
        }
    }
    else if (numberOfRows == 2)
    {
        if (indexPath.row == 0)
        {
            cell.imageURL = [NSURL URLWithString:[self imageAddressForDictionary:portraitDictionary]];
        }
        else
        {
            cell.imageURL = [NSURL URLWithString:[self imageAddressForDictionary:landscapeDictionary]];
        }
    }
    
    // Configure the cell...
    
    return cell;
}

#pragma mark - Helper Methods

- (NSDictionary *)dictionaryForSection:(NSInteger)section
{
    // Account for first section that has no cells and only a footer
    section = section - 1;
    
    return self.skinsArray[section];
}

- (NSString *)imageAddressForDictionary:(NSDictionary *)dictionary
{
    NSString *key = [GBAController keyForCurrentDeviceWithDictionary:dictionary];
    return dictionary[key];
}

- (NSString *)cachedControllerSkinInfoPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    return [cachesDirectory stringByAppendingPathComponent:@"controllerSkins.plist"];
}

@end
