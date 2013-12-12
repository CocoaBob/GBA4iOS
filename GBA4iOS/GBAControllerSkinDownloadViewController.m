//
//  GBAControllerSkinDownloadViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/2/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDownloadViewController.h"
#import "UIScreen+Widescreen.h"
#import "GBAAsynchronousRemoteTableViewCell.h"
#import "GBAControllerSkin.h"
#import "UIAlertView+RSTAdditions.h"

#import <RSTWebViewController/RSTWebViewController.h>
#import <AFNetworking/AFNetworking.h>

NSString *const GBASkinsKey = @"skins";
NSString *const GBASkinNameKey = @"name";
NSString *const GBASkinIdentifierKey = @"identifier";
NSString *const GBASkinTypeKey = @"type";
NSString *const GBASkinFilenameKey = @"filename";
NSString *const GBASkinAssetsKey = @"assets";
NSString *const GBASkinAssetPortraitKey = @"portrait";
NSString *const GBASkinAssetLandscapeKey = @"landscape";
NSString *const GBASkinDesignerKey = @"designer";
NSString *const GBASkinDesignerNameKey = @"name";
NSString *const GBASkinDesignerURLKey = @"url";

NSString *const Alyssa = @"Alyssa";

#define REMOTE_SKIN_ROOT_ADDRESS @"http://rileytestut.com/gba4ios/skins"

@interface GBAControllerSkinDownloadViewController ()

@property (copy, nonatomic) NSDictionary *skinsDictionary;
@property (strong, nonatomic) UIProgressView *downloadProgressView;
@property (strong, nonatomic) UIActivityIndicatorView *downloadingControllerSkinInfoActivityIndicatorView;
@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) NSProgress *downloadProgress;

@end

@implementation GBAControllerSkinDownloadViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        // Custom initialization
        _skinsDictionary = [NSDictionary dictionaryWithContentsOfFile:[self cachedControllerSkinInfoPath]];
        self.title = NSLocalizedString(@"Download Skins", @"");
        
        _imageCache = [[NSCache alloc] init];
        
        rst_dispatch_sync_on_main_thread(^{
            _downloadProgress = [NSProgress progressWithTotalUnitCount:1];
            [_downloadProgress addObserver:self
                                forKeyPath:@"fractionCompleted"
                                   options:NSKeyValueObservingOptionNew
                                   context:NULL];
        });
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
    
    [self downloadControllerSkinInfo];
    
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
    
    //self.hidesBottomBarWhenPushed = YES;
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    UIBarButtonItem *activityIndicatorViewButton = [[UIBarButtonItem alloc] initWithCustomView:self.downloadingControllerSkinInfoActivityIndicatorView];
    self.navigationItem.leftBarButtonItem = activityIndicatorViewButton;
    
    [self.tableView registerClass:[GBAAsynchronousRemoteTableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"HeaderFooterViewIdentifier"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Downloading

- (void)downloadControllerSkinInfo
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *address = [NSString stringWithFormat:@"%@/root.json", REMOTE_SKIN_ROOT_ADDRESS];
    NSURL *URL = [NSURL URLWithString:address];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, NSDictionary *jsonObject, NSError *error) {
        
        NSMutableDictionary *responseObject = [jsonObject mutableCopy];
        
        [self.downloadingControllerSkinInfoActivityIndicatorView stopAnimating];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            return;
        }
        
        NSMutableArray *skins = [responseObject[GBASkinsKey] mutableCopy];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@ AND (device == %@ OR device == 'Universal')", [self skinTypeString], [self deviceString]];
        [skins filterUsingPredicate:predicate];
        
        responseObject[GBASkinsKey] = skins;
        
        if ([responseObject isEqualToDictionary:self.skinsDictionary])
        {
            return;
        }
        
        self.skinsDictionary = responseObject;
        [self.skinsDictionary writeToFile:[self cachedControllerSkinInfoPath] atomically:YES];
        
        [UIView transitionWithView:self.tableView duration:0.5f options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self.tableView reloadData];
        } completion:NULL];
    }];
    
    [dataTask resume];
}

- (void)downloadSkinForDictionary:(NSDictionary *)dictionary
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *URL = [self URLForFileWithName:dictionary[GBASkinFilenameKey] identifier:dictionary[GBASkinIdentifierKey]];
    
    DLog(@"%@", URL);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    [self showDownloadProgressView];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSProgress *progress = nil;
        
        NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:&progress destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            
            NSString *filepath = [[targetPath path] stringByDeletingPathExtension];
            filepath = [filepath stringByAppendingPathExtension:@"gbaskin"];
            
            return [NSURL fileURLWithPath:filepath];
            
        } completionHandler:^(NSURLResponse *response, NSURL *fileURL, NSError *error)
                                                  {
                                                      [GBAControllerSkin extractSkinAtPathToSkinsDirectory:[fileURL path]];
                                                      
                                                      [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                                  }];
        
        [downloadTask resume];
    });
}

- (void)showDownloadProgressView
{
    [UIView animateWithDuration:0.4 animations:^{
        [self.downloadProgressView setAlpha:1.0];
    }];
}

- (void)hideDownloadProgressView
{
    [UIView animateWithDuration:0.4 animations:^{
        [self.downloadProgressView setAlpha:0.0];
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.downloadProgress)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            DLog(@"Progress: %f", self.downloadProgress.fractionCompleted);
            
            [self.downloadProgressView setProgress:self.downloadProgress.fractionCompleted animated:YES];
            
            if (self.downloadProgress.fractionCompleted == 1)
            {
                [self hideDownloadProgressView];
            }
        });
        
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Dismissal

- (void)dismiss:(UIBarButtonItem *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSArray *skins = self.skinsDictionary[GBASkinsKey];
    return [skins count] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 0;
    }
    
    NSDictionary *dictionary = [self dictionaryForSection:section];
    NSDictionary *assets = dictionary[GBASkinAssetsKey];
    
    NSInteger supportedOrientations = 0;
    
    if (assets[GBASkinAssetPortraitKey])
    {
        supportedOrientations++;
    }
    
    if (assets[GBASkinAssetLandscapeKey])
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
    
    return dictionary[GBASkinNameKey];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"You can import other .gbaskin or .gbcskin files via iTunes, or by downloading them in Safari and opening in GBA4iOS.", @"");
    }
    
    NSDictionary *dictionary = [self dictionaryForSection:section];
    NSDictionary *designer = dictionary[GBASkinDesignerKey];
    
    return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"By", @""), designer[GBASkinDesignerNameKey]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    GBAAsynchronousRemoteTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:indexPath.section];
    
    NSDictionary *dictionary = [self dictionaryForSection:indexPath.section];
    NSString *identifier = dictionary[GBASkinIdentifierKey];
    NSString *type = dictionary[GBASkinTypeKey];
    
    NSDictionary *assets = dictionary[GBASkinAssetsKey];
    
    NSDictionary *portraitAssets = assets[GBASkinAssetPortraitKey];
    NSDictionary *landscapeAssets = assets[GBASkinAssetLandscapeKey];
    
    cell.imageCache = self.imageCache;
    
    NSString *imageFilename = nil;
    
    if (numberOfRows == 1)
    {
        if (portraitAssets)
        {
            imageFilename = [self imageFilenameForDictionary:portraitAssets];
        }
        else
        {
            imageFilename = [self imageFilenameForDictionary:landscapeAssets];
        }
    }
    else if (numberOfRows == 2)
    {
        if (indexPath.row == 0)
        {
            imageFilename = [self imageFilenameForDictionary:portraitAssets];
        }
        else
        {
            imageFilename = [self imageFilenameForDictionary:landscapeAssets];
        }
    }
    
    cell.imageURL = [self URLForFileWithName:imageFilename identifier:identifier];
    
    cell.separatorInset = UIEdgeInsetsZero;
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
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

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *skinDictionary = [self dictionaryForSection:indexPath.section];
    
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to download “%@” skin?", @""), skinDictionary[GBASkinNameKey]];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Download", @""), nil];
    [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            return;
        }
        
        [self downloadSkinForDictionary:skinDictionary];
    }];
    
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - Open URL

- (void)didTapSkinDesigner:(UITapGestureRecognizer *)tapGestureRecognizer
{
    NSDictionary *dictionary = [self dictionaryForSection:tapGestureRecognizer.view.tag];
    NSDictionary *designer = dictionary[GBASkinDesignerKey];
    
    NSString *address = designer[GBASkinDesignerURLKey];
    
    if (address == nil)
    {
        return;
    }
    
    RSTWebViewController *webViewController = [[RSTWebViewController alloc] initWithAddress:address];
    [self.navigationController pushViewController:webViewController animated:YES];
}

#pragma mark - Helper Methods

- (NSDictionary *)dictionaryForSection:(NSInteger)section
{
    // Account for first section that has no cells and only a footer
    section = section - 1;
    
    NSArray *skins = self.skinsDictionary[GBASkinsKey];
    return skins[section];
}

- (NSString *)imageFilenameForDictionary:(NSDictionary *)dictionary
{
    NSString *key = [GBAControllerSkin keyForCurrentDeviceWithDictionary:dictionary];
    return dictionary[key];
}

- (NSString *)cachedControllerSkinInfoPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    return [cachesDirectory stringByAppendingPathComponent:@"controllerSkins.plist"];
}

- (NSURL *)URLForFileWithName:(NSString *)filename identifier:(NSString *)identifier
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@/%@/%@", REMOTE_SKIN_ROOT_ADDRESS, [self skinTypeString], identifier, filename]];
}

#pragma mark - Getters/Setters

- (NSString *)skinTypeString
{
    NSString *skinType = nil;
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
            skinType = @"gba";
            break;
            
        case GBAControllerSkinTypeGBC:
            skinType = @"gbc";
            break;
    }
    
    return skinType;
}

- (NSString *)deviceString
{
    NSString *deviceString = nil;
    
    switch ([[UIDevice currentDevice] userInterfaceIdiom]) {
        case UIUserInterfaceIdiomPhone:
            deviceString = @"iPhone";
            break;
            
        case UIUserInterfaceIdiomPad:
            deviceString = @"iPad";
            break;
    }
    
    return deviceString;
}

@end
