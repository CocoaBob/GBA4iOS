//
//  GBAROMTableViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROMTableViewController.h"
#import "GBAEmulationViewController.h"
#import "GBAPresentEmulationViewControllerAnimator.h"
#import "GBASettingsViewController.h"
#import "GBAPresentMenuViewControllerAnimator.h"
#import "GBATransparentTableViewHeaderFooterView.h"

#import <RSTWebViewController.h>
#import <UIAlertView+RSTAdditions.h>

#import <SSZipArchive/minizip/SSZipArchive.h>

#define LEGAL_NOTICE_ALERT_TAG 15
#define NAME_ROM_ALERT_TAG 17
#define DELETE_ROM_ALERT_TAG 2


#define RST_CONTAIN_IN_NAVIGATION_CONTROLLER(viewController)  ({ UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController]; navigationController; })

typedef NS_ENUM(NSInteger, GBAROMType) {
    GBAROMTypeAll,
    GBAROMTypeGBA,
    GBAROMTypeGBC,
};

@interface GBAROMTableViewController () <RSTWebViewControllerDelegate, UIAlertViewDelegate, UIViewControllerTransitioningDelegate>

@property (assign, nonatomic) GBAROMType romType;
@property (weak, nonatomic) IBOutlet UISegmentedControl *romTypeSegmentedControl;
@property (strong, nonatomic) NSMutableDictionary *currentDownloads;
@property (weak, nonatomic) UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *settingsButton;
@property (assign, nonatomic) GBAROMTableViewControllerTheme theme;
@property (strong, nonatomic) UIViewController *backgroundViewController;

@property (copy, nonatomic) RSTWebViewControllerStartDownloadBlock startDownloadBlock;
@property (weak, nonatomic) NSURLSessionDownloadTask *tempDownloadTask;

- (IBAction)switchROMTypes:(UISegmentedControl *)segmentedControl;
- (IBAction)searchForROMs:(UIBarButtonItem *)barButtonItem;
- (IBAction)presentSettings:(UIBarButtonItem *)barButtonItem;

@end

@implementation GBAROMTableViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        
        self.currentDirectory = documentsDirectory; 
        self.showFileExtensions = YES;
        self.showFolders = NO;
        self.showSectionTitles = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.clearsSelectionOnViewWillAppear = YES;
    
    GBAROMType romType = [[NSUserDefaults standardUserDefaults] integerForKey:@"romType"];
    self.romType = romType;
    
    self.theme = GBAROMTableViewControllerThemeOpaque;
    
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
    
    [self.tableView registerClass:[GBATransparentTableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"Header"];
    
    self.downloadProgressView = progressView;
    
    //NSFileManager *fileManager = [NSFileManager defaultManager];
    //if (![[fileManager contentsOfDirectoryAtPath:[self GBASkinsDirectory] error:NULL] containsObject:@"Default"])
    {
        NSString *filepath = [[NSBundle mainBundle] pathForResource:@"Default" ofType:@"gbaskin"];
        [self importGBASkinFromPath:filepath];
    }
    
    // iOS 6 UI
    if ([self.view respondsToSelector:@selector(setTintColor:)] == NO)
    {
        self.romTypeSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
        self.settingsButton.image = [UIImage imageNamed:@"Gear_Old"];
        self.settingsButton.landscapeImagePhone = [UIImage imageNamed:@"Gear_Landscape"];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillLayoutSubviews
{
    self.romTypeSegmentedControl.frame = ({
        CGRect frame = self.romTypeSegmentedControl.frame;
        frame.size.width = self.navigationController.navigationBar.bounds.size.width - (self.navigationItem.leftBarButtonItem.width + self.navigationItem.rightBarButtonItem.width);
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            {
                frame.size.height = 33.0f;
            }
            else
            {
                frame.size.height = 25.0f;
            }
        }
        
        frame;
    });
}

#pragma mark - RSTWebViewController delegate

- (BOOL)webViewController:(RSTWebViewController *)webViewController shouldStartDownloadWithRequest:(NSURLRequest *)request
{
    NSString *fileExtension = request.URL.pathExtension.lowercaseString;
    
    if (([fileExtension isEqualToString:@"gb"] || [fileExtension isEqualToString:@"gbc"] || [fileExtension isEqualToString:@"gba"] || [fileExtension isEqualToString:@"zip"]) || [request.URL.host hasPrefix:@"dl.coolrom"])
    {
        return YES;
    }
    
    return NO;
}

- (void)webViewController:(RSTWebViewController *)webViewController willStartDownloadWithTask:(NSURLSessionDownloadTask *)downloadTask startDownloadBlock:(RSTWebViewControllerStartDownloadBlock)startDownloadBlock
{
    if (self.currentDownloads == nil)
    {
        self.currentDownloads = [[NSMutableDictionary alloc] init];
    }
    
    self.tempDownloadTask = downloadTask;
    self.startDownloadBlock = startDownloadBlock;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"By tapping Download below, you confirm that you legally own a physical copy of this ROM. GBA4iOS does not promote pirating in any form.", @"")
                                                    message:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Download", @""), nil];
    alert.tag = LEGAL_NOTICE_ALERT_TAG;
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
            
            if (buttonIndex == 1)
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ROM Name:", @"")
                                                                message:nil
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Save", @""), nil];
                alert.alertViewStyle = UIAlertViewStylePlainTextInput;
                alert.tag = NAME_ROM_ALERT_TAG;
                
                [alert showWithCompletion:^(UIAlertView *namingAlertView, NSInteger namingButtonIndex) {
                    
                    if (namingButtonIndex == 1)
                    {
                        NSString *filename = [[alertView textFieldAtIndex:0] text];
                        [self startDownloadWithFilename:filename];
                    }
                    else
                    {
                        [self cancelDownload];
                    }
                    
                }];
            }
            else
            {
                [self cancelDownload];
            }
            
        }];
    });
}

- (void)startDownloadWithFilename:(NSString *)filename
{
    
    filename = [filename stringByAppendingPathExtension:@"gba"];
    
    // Write temp file so it shows up in the file browser, but we'll then gray it out.
    [filename writeToFile:[self.currentDirectory stringByAppendingPathComponent:filename] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableDictionary *currentDownload = [@{@"filename" : filename, @"progress" : @0} mutableCopy];
    [self.currentDownloads setObject:currentDownload forKey:self.tempDownloadTask.uniqueTaskIdentifier];
    
    self.startDownloadBlock(YES);
    
    [self refreshDirectory];
    
    [self dismissViewControllerAnimated:YES completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showDownloadProgressView];
        });
    }];
    
    self.tempDownloadTask = nil;
    self.startDownloadBlock = nil;
}

- (void)cancelDownload
{
    self.tempDownloadTask = nil;
    self.startDownloadBlock = nil;
}

- (void)webViewController:(RSTWebViewController *)webViewController downloadTask:(NSURLSessionDownloadTask *)downloadTask totalBytesDownloaded:(int64_t)totalBytesDownloaded totalBytesExpected:(int64_t)totalBytesExpected
{
    NSMutableDictionary *currentDownload = self.currentDownloads[downloadTask.uniqueTaskIdentifier];
    currentDownload[@"progress"] = @((totalBytesDownloaded * 1.0f) / (totalBytesExpected * 1.0f));
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.downloadProgressView setProgress:[self currentDownloadProgress] animated:YES];
    });
}

- (void)webViewController:(RSTWebViewController *)webViewController downloadTask:(NSURLSessionDownloadTask *)downloadTask didDownloadFileToURL:(NSURL *)fileURL
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    NSString *filename = [self.currentDownloads objectForKey:downloadTask.uniqueTaskIdentifier][@"filename"];
    NSString *destinationPath = [self.currentDirectory stringByAppendingPathComponent:filename];
    NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];
    
    NSError *error = nil;
    
    [fileManager removeItemAtURL:destinationURL error:&error];
    
    if (error)
    {
        ELog(error);
        return;
    }
    
    [fileManager moveItemAtURL:fileURL toURL:destinationURL error:&error];
    
    DLog(@"Download Complete: %@", filename);
    
    if (error)
    {
        ELog(error);
    }
}

- (void)webViewController:(RSTWebViewController *)webViewController downloadTask:(NSURLSessionDownloadTask *)downloadTask didCompleteDownloadWithError:(NSError *)error
{
    if (error)
    {
        ELog(error);
        
        NSDictionary *dictionary = self.currentDownloads[downloadTask.uniqueTaskIdentifier];
        
        NSString *filepath = [self.currentDirectory stringByAppendingPathComponent:dictionary[@"filename"]];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:filepath error:NULL];
        
        [self.currentDownloads removeObjectForKey:downloadTask.uniqueTaskIdentifier];
    }
    
    [self refreshDirectory];
    
    if ([self.currentDownloads count] == 0 || [self currentDownloadProgress] >= 1.0)
    {
        [self.currentDownloads removeAllObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideDownloadProgressView];
        });
    }
}

#pragma mark - RSTFileBrowserViewController Subclass

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    NSString *filename = [self filenameForIndexPath:indexPath];
    
    if ([self isDownloadingFile:filename])
    {
        cell.userInteractionEnabled = NO;
        cell.textLabel.textColor = [UIColor grayColor];
    }
    else
    {
        cell.userInteractionEnabled = YES;
        
        switch (self.theme) {
            case GBAROMTableViewControllerThemeOpaque:
                cell.textLabel.textColor = [UIColor blackColor];
                break;
                
            case GBAROMTableViewControllerThemeTranslucent:
                cell.textLabel.textColor = [UIColor whiteColor];
                break;
        }
        
        
    }
    
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    GBATransparentTableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"Header"];
    headerView.textLabel.text = [super tableView:tableView titleForHeaderInSection:section];
    headerView.theme = self.theme;
    
    return headerView;
}

- (NSString *)visibleFileExtensionForIndexPath:(NSIndexPath *)indexPath
{
    NSString *extension = [[super visibleFileExtensionForIndexPath:indexPath] uppercaseString];
    
    if ([extension isEqualToString:@"GB"])
    {
        extension = @"GBC";
    }
    
    return extension;
}

- (void)didRefreshCurrentDirectory
{
    [super didRefreshCurrentDirectory];
    
    NSArray *unsupportedFiles = [self.unsupportedFiles copy];
    for (NSString *file in unsupportedFiles) {
        
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"gbaskin"])
        {
            NSString *filepath = [self filepathForFile:file];
            [self importGBASkinFromPath:filepath];
        }
        
    }
}

#pragma mark - Controller Skins

- (NSString *)skinsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return [documentsDirectory stringByAppendingPathComponent:@"Skins"];
}

- (NSString *)GBASkinsDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager]; // Thread-safe as of iOS 5 WOOHOO
    NSString *gbaSkinsDirectory = [[self skinsDirectory] stringByAppendingPathComponent:@"GBA"];
    
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:gbaSkinsDirectory withIntermediateDirectories:YES attributes:nil error:&error])
    {
        ELog(error);
    }
    
    return gbaSkinsDirectory;
}

- (NSString *)GBCSkinsDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager]; // Thread-safe as of iOS 5 WOOHOO
    NSString *gbcSkinsDirectory = [[self skinsDirectory] stringByAppendingPathComponent:@"GBC"];
    
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:gbcSkinsDirectory withIntermediateDirectories:YES attributes:nil error:&error])
    {
        ELog(error);
    }
    
    return gbcSkinsDirectory;
}

- (void)importGBASkinFromPath:(NSString *)filepath
{
    NSString *destinationFilename = [filepath stringByDeletingPathExtension];
    NSString *destinationPath = [self GBASkinsDirectory];
    
    NSError *error = nil;
    
    [SSZipArchive unzipFileAtPath:filepath toDestination:destinationPath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:[destinationPath stringByAppendingPathComponent:@"__MACOSX"] error:nil];
    
    if (error)
    {
        ELog(error);
    }
}

#pragma mark - UIAlertView delegate

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    UITextField *textField = [alertView textFieldAtIndex:0];
    return [textField.text length] > 0;
}

#pragma mark - Private

- (BOOL)isDownloadingFile:(NSString *)filename
{
    __block BOOL downloadingFile = NO;
    
    NSArray *allValues = [[self.currentDownloads allValues] copy];
    [allValues enumerateObjectsUsingBlock:^(NSDictionary *dictionary, NSUInteger index, BOOL *stop) {
        NSString *downloadingFilename = dictionary[@"filename"];
        
        if ([downloadingFilename isEqualToString:filename])
        {
            downloadingFile = YES;
            *stop = YES;
        }
    }];
    
    return downloadingFile;
}

- (CGFloat)currentDownloadProgress
{
    CGFloat currentProgress = 0.0;
    CGFloat totalProgress = 0.0;
    
    NSArray *allValues = [[self.currentDownloads allValues] copy]; // So it's not changed while enumerating. Bitten by that quite a few times in the past. Not fun. Trust me.
    
    for (NSDictionary *dictionary in allValues) {
        currentProgress += [dictionary[@"progress"] floatValue];
        totalProgress += 1.0f;
    }
    
    return currentProgress/totalProgress;
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

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *filepath = [self filepathForIndexPath:indexPath];
    
    GBAEmulationViewController *emulationViewController = [[GBAEmulationViewController alloc] initWithROMFilepath:filepath];
    emulationViewController.skinFilepath = [[self GBASkinsDirectory] stringByAppendingPathComponent:@"Default"];
    
    if ([emulationViewController respondsToSelector:@selector(setTransitioningDelegate:)])
    {
        emulationViewController.transitioningDelegate = self;
    }
    
    [self presentViewController:emulationViewController animated:YES completion:NULL];
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Test" message:@"AWESOME" cancelButtonTitle:@"Cancel" otherButtonTitles:@"SWEET", @"COOL", nil];
        UIView *contentView = [alert valueForKey:@"contentViewNeue"];
        
        [contentView addSubview:[[UISegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 200, 44)]];
        [alert showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex)
        {
            if (buttonIndex == 0)
            {
                DLog(@"Canceled");
            }
            else if (buttonIndex == 1)
            {
                DLog(@"Sweet");
            }
            else if (buttonIndex == 2)
            {
                DLog(@"COOL");
            }
        }];
    }
}

#pragma mark - Presenting/Dismissing Emulation View Controller

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    GBAPresentEmulationViewControllerAnimator *animator = [[GBAPresentEmulationViewControllerAnimator alloc] init];
    
    animator.completionBlock = ^{
        [self removeViewControllerFromBackground];
    };
    return animator;
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    GBAPresentMenuViewControllerAnimator *animator = [[GBAPresentMenuViewControllerAnimator alloc] init];
    
    __weak GBAPresentMenuViewControllerAnimator *weakAnimator = animator;
    
    animator.completionBlock = ^{
        [self placeViewControllerInBackground:weakAnimator.emulationViewController];
    };
    //self.theme = GBAROMTableViewControllerThemeTranslucent;
    
    return animator;
}

- (void)placeViewControllerInBackground:(UIViewController *)viewController
{
    UIView *view = viewController.view;
    view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    [viewController willMoveToParentViewController:self];
    [self addChildViewController:viewController];
    [self.tableView.backgroundView insertSubview:view atIndex:0];
    [viewController willMoveToParentViewController:self];
    [viewController didMoveToParentViewController:self];
    
    self.backgroundViewController = viewController;
}

- (void)removeViewControllerFromBackground
{
    UIView *view = self.backgroundViewController.view;
    
    [self.backgroundViewController willMoveToParentViewController:nil];
    [self.backgroundViewController removeFromParentViewController];
    [view removeFromSuperview];
    [self.backgroundViewController willMoveToParentViewController:nil];
    [self.backgroundViewController didMoveToParentViewController:nil];
    
    self.backgroundViewController = nil;
}

#pragma mark - IBActions

- (IBAction)switchROMTypes:(UISegmentedControl *)segmentedControl
{
    GBAROMType romType = segmentedControl.selectedSegmentIndex;
    self.romType = romType;
}

- (IBAction)searchForROMs:(UIBarButtonItem *)barButtonItem
{
    NSString *address = @"http://www.google.com/search?hl=en&source=hp&q=download+ROMs+gba+gameboy+advance&aq=f&oq=&aqi=";
    
    if (![NSURLSession class]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:address]];
        
        return;
    }
    
    RSTWebViewController *webViewController = [[RSTWebViewController alloc] initWithAddress:address];
    webViewController.showDoneButton = YES;
    webViewController.delegate = self;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    [self presentViewController:navigationController animated:YES completion:NULL];
}

- (IBAction)presentSettings:(UIBarButtonItem *)barButtonItem
{
    GBASettingsViewController *settingsViewController = [[GBASettingsViewController alloc] init];
    settingsViewController.theme = self.theme;
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(settingsViewController) animated:YES completion:NULL];
}

#pragma mark - Getters/Setters

- (void)setRomType:(GBAROMType)romType
{
    self.romTypeSegmentedControl.selectedSegmentIndex = romType;
    [[NSUserDefaults standardUserDefaults] setInteger:romType forKey:@"romType"];
    
    switch (romType) {
        case GBAROMTypeAll:
            self.supportedFileExtensions = @[@"gba", @"gbc", @"gb", @"zip"];
            break;
            
        case GBAROMTypeGBA:
            self.supportedFileExtensions = @[@"gba"];
            break;
            
        case GBAROMTypeGBC:
            self.supportedFileExtensions = @[@"gb", @"gbc"];
            break;
    }
    
    _romType = romType;
}

- (void)setTheme:(GBAROMTableViewControllerTheme)theme
{
    if (_theme == theme)
    {
        return;
    }
    
    _theme = theme;
    
    /*switch (theme) {
        case GBAROMTableViewControllerThemeTranslucent: {
            self.tableView.backgroundColor = [UIColor clearColor];
            self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
            
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [UIColor clearColor];
            
            self.tableView.backgroundView = view;
            
            [self.romTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
            [self.romTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
            
            //self.tableView.rowHeight = 600;
            
            break;
        }
            
        case GBAROMTableViewControllerThemeOpaque:
            self.tableView.backgroundColor = [UIColor whiteColor];
            self.tableView.backgroundView = nil;
            self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
            
            
            break;
    }*/
    
    [self.tableView reloadData];
}


@end
