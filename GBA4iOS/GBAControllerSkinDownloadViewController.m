//
//  GBAControllerSkinDownloadViewController.m
//  GBA4iOS
//
//  Created by Yvette Testut on 9/2/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDownloadViewController.h"
#import "UIScreen+Widescreen.h"
#import "GBAControllerSkinPreviewCell.h"

#define CONTROLLER_SKIN_DOWNLOAD_PLIST_URL [NSURL URLWithString:@"http://rileytestut.com/gba4ios/skins/root.plist"]

@interface GBAControllerSkinDownloadViewController ()

@property (copy, nonatomic) NSArray *skinsArray;
@property (strong, nonatomic) UIProgressView *downloadProgressView;
@property (strong, nonatomic) UIActivityIndicatorView *downloadingControllerSkinInfoActivityIndicatorView;

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
    
    [self.tableView registerClass:[GBAControllerSkinPreviewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Downloading

- (void)downloadControllerSkinInfo
{
    self.skinsArray = [NSArray arrayWithContentsOfURL:CONTROLLER_SKIN_DOWNLOAD_PLIST_URL];
    [self.skinsArray writeToFile:[self cachedControllerSkinInfoPath] atomically:YES];
    
    [self.downloadingControllerSkinInfoActivityIndicatorView stopAnimating];
    
    DLog(@"%@", self.downloadingControllerSkinInfoActivityIndicatorView);
    [self.tableView reloadData];
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
    
    if (dictionary[@"portraitImage"])
    {
        supportedOrientations++;
    }
    
    if (dictionary[@"landscapeImage"])
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
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

- (NSString *)cachedControllerSkinInfoPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    return [cachesDirectory stringByAppendingPathComponent:@"controllerSkins.plist"];
}

@end
