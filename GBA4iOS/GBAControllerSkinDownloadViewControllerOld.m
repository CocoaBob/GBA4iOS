//
//  GBAControllerSkinDownloadViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/2/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDownloadViewControllerOld.h"
#import "UIScreen+Size.h"
#import "GBAAsynchronousRemoteTableViewCell.h"
#import "GBAControllerSkin_Private.h"
#import "UIAlertView+RSTAdditions.h"

#import <RSTWebViewController.h>
#import <AFNetworking/AFNetworking.h>

NSString *const GBASkinsKey = @"skins";
NSString *const GBASkinFilenameKey = @"filename";
NSString *const GBASkinDesignerKey = @"designer";
NSString *const GBASkinDesignerNameKey = @"name";
NSString *const GBASkinDesignerURLKey = @"url";

NSString *const Alyssa = @"Alyssa";

static void * GBADownloadProgressContext = &GBADownloadProgressContext;
static void * GBADownloadProgressTotalUnitContext = &GBADownloadProgressTotalUnitContext;

#define REMOTE_SKIN_ROOT_ADDRESS @"http://gba4iosapp.com/delta/skins_legacy/"

@interface GBAControllerSkinDownloadViewControllerOld ()

@property (copy, nonatomic) NSDictionary *skinsDictionary;
@property (strong, nonatomic) UIProgressView *downloadProgressView;
@property (strong, nonatomic) UIActivityIndicatorView *downloadingControllerSkinInfoActivityIndicatorView;
@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) NSProgress *downloadProgress;

@end

@implementation GBAControllerSkinDownloadViewControllerOld

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        // Custom initialization
        self.title = NSLocalizedString(@"Download Skins", @"");
        
        _imageCache = [[NSCache alloc] init];
        
        _downloadProgress = ({
            NSProgress *progress = [[NSProgress alloc] initWithParent:nil userInfo:0];
            progress;
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
    else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        self.tableView.rowHeight = 230;
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
    
    NSString *address = [REMOTE_SKIN_ROOT_ADDRESS stringByAppendingPathComponent:@"root.json"];
    NSURL *URL = [NSURL URLWithString:address];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, NSDictionary *jsonObject, NSError *error) {
        
        NSMutableDictionary *responseObject = [jsonObject mutableCopy];
        
        [self.downloadingControllerSkinInfoActivityIndicatorView stopAnimating];
        
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithError:error];
                [alert show];
            });
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
        
        [self updateTableViewWithAnimation];
    }];
    
    [dataTask resume];
}

- (void)downloadSkinForDictionary:(NSDictionary *)dictionary
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *URL = [self URLForFileWithName:dictionary[GBASkinFilenameKey] identifier:dictionary[GBAControllerSkinIdentifierKey]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    if (self.downloadProgressView.alpha == 0)
    {
        rst_dispatch_sync_on_main_thread(^{
            [self showDownloadProgressView];
        });
    }
    
    NSProgress *progress = nil;
    
    __strong NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:&progress destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        
        NSString *filepath = [[targetPath path] stringByDeletingPathExtension];
        
        switch (self.controllerSkinType)
        {
            case GBAControllerSkinTypeGBA:
                filepath = [filepath stringByAppendingPathExtension:@"gbaskin"];
                break;
                
            case GBAControllerSkinTypeGBC:
                filepath = [filepath stringByAppendingPathExtension:@"gbcskin"];
                break;
        }
        
        
        
        return [NSURL fileURLWithPath:filepath];
        
    } completionHandler:^(NSURLResponse *response, NSURL *fileURL, NSError *error)
                                              {
                                                  if (error)
                                                  {
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          UIAlertView *alert = [[UIAlertView alloc] initWithError:error];
                                                          [alert show];
                                                      });
                                                      
                                                      [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                                      
                                                      return;
                                                  }
                                                  
                                                  [GBAControllerSkin extractSkinAtPathToSkinsDirectory:[fileURL path]];
                                                  
                                                  [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                              }];
    
    [progress addObserver:self forKeyPath:@"totalUnitCount" options:NSKeyValueObservingOptionNew context:GBADownloadProgressTotalUnitContext];
    [progress addObserver:self forKeyPath:@"completedUnitCount" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:GBADownloadProgressContext];
    
    [downloadTask resume];
}

- (void)showDownloadProgressView
{
    self.downloadProgress.totalUnitCount = 0;
    self.downloadProgress.completedUnitCount = 0;
    
    [UIView animateWithDuration:0.4 animations:^{
        [self.downloadProgressView setAlpha:1.0];
    }];
}

- (void)hideDownloadProgressView
{
    [UIView animateWithDuration:0.4 animations:^{
        [self.downloadProgressView setAlpha:0.0];
    } completion:^(BOOL finisehd) {
        self.downloadProgressView.progress = 0.0;
    }];
    
    self.downloadProgress.totalUnitCount = 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == GBADownloadProgressContext)
    {
        NSProgress *progress = object;
        
        rst_dispatch_sync_on_main_thread(^{
            
            int64_t previousProgress = [change[NSKeyValueChangeOldKey] integerValue];
            int64_t currentProgress = [change[NSKeyValueChangeNewKey] integerValue];
            
            self.downloadProgress.completedUnitCount = self.downloadProgress.completedUnitCount + (currentProgress - previousProgress);
            [self.downloadProgressView setProgress:self.downloadProgress.fractionCompleted animated:YES];
            
            DLog(@"%f", self.downloadProgress.fractionCompleted);
            
            if (progress.fractionCompleted == 1)
            {
                [progress removeObserver:self forKeyPath:@"completedUnitCount" context:GBADownloadProgressContext];
            }
            
            if (self.downloadProgress.fractionCompleted == 1)
            {
                [self hideDownloadProgressView];
            }
        });
        
        return;
    }
    else if (context == GBADownloadProgressTotalUnitContext)
    {
        NSProgress *progress = object;
        
        if (self.downloadProgressView.alpha == 0)
        {
            rst_dispatch_sync_on_main_thread(^{
                [self showDownloadProgressView];
            });
        }
        
        [self.downloadProgress setTotalUnitCount:self.downloadProgress.totalUnitCount + progress.totalUnitCount];
        
        [progress removeObserver:self forKeyPath:@"totalUnitCount" context:GBADownloadProgressTotalUnitContext];
        
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)updateTableViewWithAnimation
{
    NSArray *skins = self.skinsDictionary[GBASkinsKey];
    NSInteger currentNumberOfSections = self.tableView.numberOfSections;
    
    [self.tableView beginUpdates];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, currentNumberOfSections)] withRowAnimation:UITableViewRowAnimationFade];
    
    if ((int)[skins count] > currentNumberOfSections - 1)
    {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(currentNumberOfSections, skins.count - (currentNumberOfSections - 1))] withRowAnimation:UITableViewRowAnimationFade];
    }
    
    [self.tableView endUpdates];
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
    NSDictionary *assets = dictionary[GBAControllerSkinAssetsKey];
    
    NSInteger supportedOrientations = 0;
    
    if (assets[GBAControllerSkinOrientationPortraitKey])
    {
        supportedOrientations++;
    }
    
    if (assets[GBAControllerSkinOrientationLandscapeKey])
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
    
    return dictionary[GBAControllerSkinNameKey];
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
    NSString *identifier = dictionary[GBAControllerSkinIdentifierKey];
    NSString *type = dictionary[GBAControllerSkinTypeKey];
    
    NSDictionary *assets = dictionary[GBAControllerSkinAssetsKey];
    
    NSString *filename = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        filename = assets[GBAScreenTypeResizableiPad];
    }
    else
    {
        filename = assets[GBAScreenTypeResizableiPhone];
    }
    
    BOOL resizable = (filename != nil);
    
    NSDictionary *portraitAssets = assets[GBAControllerSkinOrientationPortraitKey];
    NSDictionary *landscapeAssets = assets[GBAControllerSkinOrientationLandscapeKey];
    
    cell.imageCache = self.imageCache;
    
    NSString *imageFilename = nil;
    
    if (numberOfRows == 1)
    {
        if (portraitAssets)
        {
            imageFilename = [self imageFilenameForDictionary:portraitAssets resizable:resizable];
        }
        else
        {
            imageFilename = [self imageFilenameForDictionary:landscapeAssets resizable:resizable];
        }
    }
    else if (numberOfRows == 2)
    {
        if (indexPath.row == 0)
        {
            imageFilename = [self imageFilenameForDictionary:portraitAssets resizable:resizable];
        }
        else
        {
            imageFilename = [self imageFilenameForDictionary:landscapeAssets resizable:resizable];
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
    
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to download “%@” skin?", @""), skinDictionary[GBAControllerSkinNameKey]];
    
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
    if (section == 0)
    {
        return nil;
    }
    
    // Account for first section that has no cells and only a footer
    section = section - 1;
    
    NSArray *skins = self.skinsDictionary[GBASkinsKey];
    return skins[section];
}

- (NSString *)imageFilenameForDictionary:(NSDictionary *)dictionary resizable:(BOOL)resizable
{
    NSString *key = nil;//[GBAControllerSkin screenTypeForCurrentDeviceWithDictionary:dictionary resizable:resizable];
    return dictionary[key];
}

- (NSString *)cachedControllerSkinInfoPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *skinType = nil;
    
    switch (self.controllerSkinType)
    {
        case GBAControllerSkinTypeGBA:
            skinType = @"GBA";
            break;
            
        case GBAControllerSkinTypeGBC:
            skinType = @"GBC";
            break;
    }
    
    NSString *filename = [NSString stringWithFormat:@"controllerSkins_%@.plist", skinType];
    
    return [cachesDirectory stringByAppendingPathComponent:filename];
}

- (NSURL *)URLForFileWithName:(NSString *)filename identifier:(NSString *)identifier
{
    NSString *address = [REMOTE_SKIN_ROOT_ADDRESS stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/%@", [self skinTypeString], identifier, filename]];
    return [NSURL URLWithString:address];
}

#pragma mark - Getters/Setters

- (NSDictionary *)skinsDictionary
{
    if (_skinsDictionary == nil)
    {
        _skinsDictionary = [NSDictionary dictionaryWithContentsOfFile:[self cachedControllerSkinInfoPath]];
    }
    
    return _skinsDictionary;
}

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
    
    switch ([[UIDevice currentDevice] userInterfaceIdiom])
    {
        case UIUserInterfaceIdiomPhone:
        case UIUserInterfaceIdiomUnspecified:
            deviceString = @"iPhone";
            break;
            
        case UIUserInterfaceIdiomPad:
            deviceString = @"iPad";
            break;
    }
    
    return deviceString;
}

@end
