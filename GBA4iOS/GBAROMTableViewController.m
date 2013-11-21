//
//  GBAROMTableViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROMTableViewController.h"
#import "GBAEmulationViewController.h"
#import "GBASettingsViewController.h"
#import "GBAROM.h"
#import "RSTFileBrowserTableViewCell+LongPressGestureRecognizer.h"
#import "GBAMailActivity.h"
#import "GBASplitViewController.h"
#import "UITableViewController+Theming.h"

#import <RSTWebViewController.h>
#import <UIAlertView+RSTAdditions.h>
#import <RSTActionSheet/UIActionSheet+RSTAdditions.h>

#import <SSZipArchive/minizip/SSZipArchive.h>
#import <DropboxSDK/DropboxSDK.h>

#define LEGAL_NOTICE_ALERT_TAG 15
#define NAME_ROM_ALERT_TAG 17
#define DELETE_ROM_ALERT_TAG 2
#define RENAME_GESTURE_RECOGNIZER_TAG 22

typedef NS_ENUM(NSInteger, GBAVisibleROMType) {
    GBAVisibleROMTypeAll,
    GBAVisibleROMTypeGBA,
    GBAVisibleROMTypeGBC,
};

@interface GBAROMTableViewController () <RSTWebViewControllerDownloadDelegate, UIAlertViewDelegate, UIViewControllerTransitioningDelegate, UIPopoverControllerDelegate, RSTWebViewControllerDelegate, GBASettingsViewControllerDelegate>

@property (assign, nonatomic) GBAVisibleROMType visibleRomType;
@property (weak, nonatomic) IBOutlet UISegmentedControl *romTypeSegmentedControl;
@property (strong, nonatomic) NSMutableDictionary *currentDownloads;
@property (strong, nonatomic) NSMutableSet *currentUnzippingOperations;
@property (weak, nonatomic) UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *settingsButton;
@property (strong, nonatomic) UIPopoverController *activityPopoverController;

@property (copy, nonatomic) RSTWebViewControllerStartDownloadBlock startDownloadBlock;
@property (weak, nonatomic) NSURLSessionDownloadTask *tempDownloadTask;

- (IBAction)switchROMTypes:(UISegmentedControl *)segmentedControl;
- (IBAction)searchForROMs:(UIBarButtonItem *)barButtonItem;
- (IBAction)presentSettings:(UIBarButtonItem *)barButtonItem;

@end

@implementation GBAROMTableViewController
@synthesize theme = _theme;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"romTableViewController"];
    if (self)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        
        self.currentDirectory = documentsDirectory; 
        self.showFileExtensions = YES;
        self.showFolders = NO;
        self.showSectionTitles = NO;
        self.showUnavailableFiles = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.clearsSelectionOnViewWillAppear = YES;
    
    GBAVisibleROMType romType = [[NSUserDefaults standardUserDefaults] integerForKey:@"visibleROMType"];
    self.romType = romType;
    
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
    
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"Header"];
    
    self.downloadProgressView = progressView;
    
    //NSFileManager *fileManager = [NSFileManager defaultManager];
    //if (![[fileManager contentsOfDirectoryAtPath:[self GBASkinsDirectory] error:NULL] containsObject:@"Default"])
    {
        [self importDefaultSkins];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarStyle:[self preferredStatusBarStyle] animated:YES];
    
    // Sometimes it loses its color when the view appears
    self.downloadProgressView.progressTintColor = GBA4iOS_PURPLE_COLOR;
    
    if ([self.appearanceDelegate respondsToSelector:@selector(romTableViewControllerWillAppear:)])
    {
        [self.appearanceDelegate romTableViewControllerWillAppear:self];
    }
    
    if (self.emulationViewController.rom && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) // Show selected ROM
    {
        [self.tableView reloadData];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([self.appearanceDelegate respondsToSelector:@selector(romTableViewControllerWillDisappear:)])
    {
        [self.appearanceDelegate romTableViewControllerWillDisappear:self];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DLog(@"ROM list appeared");
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    self.romTypeSegmentedControl.frame = ({
        CGRect frame = self.romTypeSegmentedControl.frame;
        frame.size.width = self.navigationController.navigationBar.bounds.size.width - (self.navigationItem.leftBarButtonItem.width + self.navigationItem.rightBarButtonItem.width);
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            {
                frame.size.height = 29.0f;
            }
            else
            {
                frame.size.height = 25.0f;
            }
        }
        
        frame;
    });
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (self.theme == GBAThemedTableViewControllerThemeOpaque)
    {
        return UIStatusBarStyleDefault;
    }
    
    return UIStatusBarStyleLightContent;
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
                                                    message:nil delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Download", @""), nil];
    alert.tag = LEGAL_NOTICE_ALERT_TAG;
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            
            if (buttonIndex == 1)
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ROM Name", @"")
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Save", @""), nil];
                alert.alertViewStyle = UIAlertViewStylePlainTextInput;
                alert.tag = NAME_ROM_ALERT_TAG;
                
                UITextField *textField = [alert textFieldAtIndex:0];
                textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
                
                [alert showWithSelectionHandler:^(UIAlertView *namingAlertView, NSInteger namingButtonIndex) {
                    
                    if (namingButtonIndex == 1)
                    {
                        NSString *filename = [[namingAlertView textFieldAtIndex:0] text];
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
    if ([filename length] == 0)
    {
        filename = @" ";
    }
    
    NSString *fileExtension = self.tempDownloadTask.originalRequest.URL.pathExtension;
    
    if (fileExtension == nil || [fileExtension isEqualToString:@""])
    {
        fileExtension = @"zip";
    }
    
    filename = [filename stringByAppendingPathExtension:fileExtension];
    
    // Write temp file so it shows up in the file browser, but we'll then gray it out.
    [filename writeToFile:[self.currentDirectory stringByAppendingPathComponent:filename] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableDictionary *currentDownload = [@{@"filename" : filename, @"progress" : @0} mutableCopy];
    [self.currentDownloads setObject:currentDownload forKey:self.tempDownloadTask.uniqueTaskIdentifier];
    
    self.startDownloadBlock(YES);
    
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
    
    [self setIgnoreDirectoryContentChanges:YES];
    
    [fileManager removeItemAtURL:destinationURL error:&error];
    
    if (error)
    {
        ELog(error);
        return;
    }
    
    NSURL *remoteURL = downloadTask.originalRequest.URL;
    
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
    [[NSFileManager defaultManager] moveItemAtURL:fileURL toURL:destinationURL error:nil];
        
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
        
    if ([self.currentDownloads count] == 0 || [self currentDownloadProgress] >= 1.0)
    {
        [self.currentDownloads removeAllObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideDownloadProgressView];
        });
    }
    
    [self setIgnoreDirectoryContentChanges:NO];
}

- (void)webViewControllerWillDismiss:(RSTWebViewController *)webViewController
{
    
    [self dismissedModalViewController];
}

#pragma mark - UITableViewController data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RSTFileBrowserTableViewCell *cell = (RSTFileBrowserTableViewCell *)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    NSString *filename = [self filenameForIndexPath:indexPath];
    
    [self themeTableViewCell:cell];
    
    if ([self isDownloadingFile:filename] || [self.unavailableFiles containsObject:filename])
    {
        cell.userInteractionEnabled = NO;
        cell.textLabel.textColor = [UIColor grayColor];
    }
    else
    {
        GBAROMType romType = GBAROMTypeGBA;
        
        if ([[[filename pathExtension] lowercaseString] isEqualToString:@"gbc"] || [[[filename pathExtension] lowercaseString] isEqualToString:@"gb"])
        {
            romType = GBAROMTypeGBC;
        }
        
        if ([self.emulationViewController.rom.name isEqualToString:[filename stringByDeletingPathExtension]] && self.emulationViewController.rom.type == romType)
        {
            [self highlightCell:cell];
        }
        
        cell.userInteractionEnabled = YES;
    }
    
    if (cell.longPressGestureRecognizer == nil)
    {
        UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didDetectLongPressGesture:)];
        [cell setLongPressGestureRecognizer:longPressGestureRecognizer];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UITableViewHeaderFooterView *headerView = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"Header"];
    [self themeHeader:headerView];
    
    return headerView;
}

#pragma mark - RSTFileBrowserViewController

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
    
    if ([self ignoreDirectoryContentChanges])
    {
        return;
    }
    
    NSArray *contents = [self allFiles];
    
    for (NSString *filename in contents)
    {
        if ([[filename lowercaseString] hasSuffix:@"zip"] && ![self isDownloadingFile:filename] && ![self.unavailableFiles containsObject:filename])
        {
            [self setIgnoreDirectoryContentChanges:YES];
            
            NSString *filepath = [self.currentDirectory stringByAppendingPathComponent:filename];
            
            NSError *error = nil;
            if (![GBAROM unzipROMAtPathToROMDirectory:filepath withPreferredROMTitle:[filename stringByDeletingPathExtension] error:&error])
            {
                if ([error code] == NSFileWriteFileExistsError)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File Already Exists", @"")
                                                                        message:NSLocalizedString(@"Please rename either the existing file or the file to be imported and try again.", @"")
                                                                       delegate:nil
                                                              cancelButtonTitle:NSLocalizedString(@"Dismiss", @"") otherButtonTitles:nil];
                        [alert show];
                    });
                }
                else if ([error code] == NSFileReadNoSuchFileError)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Unsupported File", @"")
                                                                        message:NSLocalizedString(@"Make sure the zip file contains either a GBA or GBC ROM and try again,", @"")
                                                                       delegate:nil
                                                              cancelButtonTitle:NSLocalizedString(@"Dismiss", @"") otherButtonTitles:nil];
                        [alert show];
                    });
                    
                }
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
            
            [self setIgnoreDirectoryContentChanges:NO];
        }
    }
}

#pragma mark - Directories

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

- (NSString *)saveStateDirectoryFovrROM:(GBAROM *)rom
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *saveStateDirectory = [documentsDirectory stringByAppendingPathComponent:@"Save States"];
    
    return [saveStateDirectory stringByAppendingPathComponent:rom.name];
}

- (NSString *)cheatCodeFileForROM:(GBAROM *)rom
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *cheatCodeDirectory = [documentsDirectory stringByAppendingPathComponent:@"Cheats"];
    
    return nil;
}

#pragma mark - Controller Skins

- (void)importDefaultSkins
{
    [self importDefaultGBASkin];
    [self importDefaultGBCSkin];
}

- (void)importDefaultGBASkin
{
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"Default" ofType:@"gbaskin"];
    
    [[NSFileManager defaultManager] removeItemAtPath:[[self GBASkinsDirectory] stringByAppendingPathComponent:@"com.GBA4iOS.default"] error:nil];
        
    [GBAController extractSkinAtPathToSkinsDirectory:filepath];
}

- (void)importDefaultGBCSkin
{
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"Default" ofType:@"gbcskin"];
    
    [[NSFileManager defaultManager] removeItemAtPath:[[self GBCSkinsDirectory] stringByAppendingPathComponent:@"com.GBA4iOS.default"] error:nil];
    
    [GBAController extractSkinAtPathToSkinsDirectory:filepath];
}

#pragma mark - UIAlertView delegate

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    NSString *filename = [[alertView textFieldAtIndex:0] text];
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.currentDirectory error:nil];
    BOOL fileExists = NO;
    
    for (NSString *item in contents)
    {
        if ([[[item pathExtension] lowercaseString] isEqualToString:@"gba"] || [[[item pathExtension] lowercaseString] isEqualToString:@"gbc"] ||
            [[[item pathExtension] lowercaseString] isEqualToString:@"gb"] || [[[item pathExtension] lowercaseString] isEqualToString:@"zip"])
        {
            NSString *name = [item stringByDeletingPathExtension];
            
            if ([name isEqualToString:filename])
            {
                fileExists = YES;
                break;
            }
        }
    }
    
    if (fileExists)
    {
        alertView.title = NSLocalizedString(@"File Already Exists", @"");
    }
    else
    {
        alertView.title = NSLocalizedString(@"ROM Name", @"");
    }
    
    return filename.length > 0 && !fileExists;
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

- (void)dismissedModalViewController
{
    [self.tableView reloadData]; // Fixes incorrectly-sized cell dividers after changing orientation when a modal view controller is shown
    [self.emulationViewController refreshLayout];
}

- (void)highlightCell:(UITableViewCell *)cell
{
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    backgroundView.backgroundColor = GBA4iOS_PURPLE_COLOR;
    backgroundView.alpha = 0.6;
    cell.backgroundView = backgroundView;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[DBSession sharedSession] isLinked] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"hasPerformedInitialSync"])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Syncing with Dropbox", @"")
                                                        message:NSLocalizedString(@"Please wait for the initial sync to be complete, then launch the ROM. This is to ensure no save data is lost.", @"")
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"Dismiss", @"") otherButtonTitles:nil];
        [alert show];
        
        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
        return;
    }
    
    NSString *filepath = [self filepathForIndexPath:indexPath];
    
    GBAROM *rom = [GBAROM romWithContentsOfFile:filepath];
    
    void(^showEmulationViewController)(void) = ^(void)
    {
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [self dismissViewControllerAnimated:YES completion:^{
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                [self highlightCell:cell];
            }];
        }
        else
        {
            [(GBASplitViewController *)self.splitViewController hideROMTableViewControllerWithAnimation:YES];
            
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [self highlightCell:cell];
        }
    };
    
    if ([self.emulationViewController.rom isEqual:rom])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ROM already in use", @"")
                                                        message:NSLocalizedString(@"Would you like to resume where you left off, or restart the ROM?", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                              otherButtonTitles:NSLocalizedString(@"Resume", @""), NSLocalizedString(@"Restart", @""), nil];
        [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 0)
            {
                [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
            }
            else if (buttonIndex == 1)
            {
                showEmulationViewController();
            }
            else if (buttonIndex == 2)
            {
                self.emulationViewController.rom = rom;
                
                showEmulationViewController();
            }
                
        }];
    }
    else
    {
        self.emulationViewController.rom = rom;
        
        showEmulationViewController();
        
    }
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to delete this ROM and all of its saved data? This cannot be undone.", nil)
                                                                 delegate:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle:NSLocalizedString(@"Delete ROM and Saved Data", nil)
                                                        otherButtonTitles:nil];
        
        UIView *presentationView = self.view;
        CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            presentationView = self.splitViewController.view;
            rect = [presentationView convertRect:rect fromView:self.tableView];
        }
        
        [actionSheet showFromRect:rect inView:presentationView animated:YES selectionHandler:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
            
            if (buttonIndex == 0)
            {
                [self deleteROMAtIndexPath:indexPath];
            }
        }];
    }
}

#pragma mark - Deleting/Renaming/Sharing

- (void)didDetectLongPressGesture:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan)
    {
        return;
    }
    
    UITableViewCell *cell = (UITableViewCell *)[gestureRecognizer view];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:nil
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedString(@"Rename ROM", @""), NSLocalizedString(@"Share ROM", @""), nil];
    UIView *presentationView = self.view;
    CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        presentationView = self.splitViewController.view;
        rect = [presentationView convertRect:rect fromView:self.tableView];
    }
    
    [actionSheet showFromRect:rect inView:presentationView animated:YES selectionHandler:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
         if (buttonIndex == 0)
         {
             [self showRenameAlertForROMAtIndexPath:indexPath];
         }
        else if (buttonIndex == 1)
        {
            [self shareROMAtIndexPath:indexPath];
        }
     }];
    
}

- (void)showRenameAlertForROMAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *filepath = [self filepathForIndexPath:indexPath];
    NSString *romName = [[filepath lastPathComponent] stringByDeletingPathExtension];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Rename ROM", @"") message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Rename", @""), nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    
    UITextField *textField = [alert textFieldAtIndex:0];
    textField.text = romName;
    textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    
#warning Present Alert if ROM is running in background
    
    [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 1)
        {
            UITextField *textField = [alertView textFieldAtIndex:0];
            [self renameROMAtIndexPath:indexPath toName:textField.text];
        }
    }];
}

- (void)deleteROMAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *filepath = [self filepathForIndexPath:indexPath];
    NSString *romName = [[filepath lastPathComponent] stringByDeletingPathExtension];
    
    NSString *saveFile = [NSString stringWithFormat:@"%@.sav", romName];
    NSString *rtcFile = [NSString stringWithFormat:@"%@.rtc", romName];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *cheatsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Cheats"];
    NSString *saveStateDirectory = [documentsDirectory stringByAppendingPathComponent:@"Save States"];
    
    NSString *cheatsFilename = [NSString stringWithFormat:@"%@.plist", romName];
    
    [[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:saveFile] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:rtcFile] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[saveStateDirectory stringByAppendingPathComponent:romName] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[cheatsDirectory stringByAppendingPathComponent:cheatsFilename] error:nil];
    
    [self deleteFileAtIndexPath:indexPath animated:YES];
}

- (void)renameROMAtIndexPath:(NSIndexPath *)indexPath toName:(NSString *)newName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *filepath = [self filepathForIndexPath:indexPath];
    NSString *extension = [filepath pathExtension];
    
    NSString *romName = [[filepath lastPathComponent] stringByDeletingPathExtension];
    NSString *newRomFilename = [NSString stringWithFormat:@"%@.%@", newName, extension]; // Includes extension
    
    NSString *saveFile = [NSString stringWithFormat:@"%@.sav", romName];
    NSString *newSaveFile = [NSString stringWithFormat:@"%@.sav", newName];
    
    NSString *cheatsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Cheats"];
    NSString *saveStateDirectory = [documentsDirectory stringByAppendingPathComponent:@"Save States"];
    
    NSString *cheatsFilename = [NSString stringWithFormat:@"%@.plist", romName];
    NSString *newCheatsFilename = [NSString stringWithFormat:@"%@.plist", newName];
    
    [[NSFileManager defaultManager] moveItemAtPath:filepath toPath:[documentsDirectory stringByAppendingPathComponent:newRomFilename] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[documentsDirectory stringByAppendingPathComponent:saveFile] toPath:[documentsDirectory stringByAppendingPathComponent:newSaveFile] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[cheatsDirectory stringByAppendingPathComponent:cheatsFilename] toPath:[cheatsDirectory stringByAppendingPathComponent:newCheatsFilename] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[saveStateDirectory stringByAppendingPathComponent:romName] toPath:[saveStateDirectory stringByAppendingPathComponent:newName] error:nil];
}

- (void)shareROMAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *romFilepath = [self filepathForIndexPath:indexPath];
    
    NSString *romName = [[romFilepath lastPathComponent] stringByDeletingPathExtension];
    NSString *saveFilepath = [documentsDirectory stringByAppendingPathComponent:[romName stringByAppendingString:@".sav"]];
    
    NSURL *romFileURL = [NSURL fileURLWithPath:romFilepath];
    NSURL *saveFileURL = [NSURL fileURLWithPath:saveFilepath];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[romFileURL] applicationActivities:@[[[GBAMailActivity alloc] init]]];
    activityViewController.excludedActivityTypes = @[UIActivityTypeMessage, UIActivityTypeMail]; // Can't install from Messages app, and we use our own Mail activity that supports custom file types
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [self presentViewController:activityViewController animated:YES completion:NULL];
    }
    else
    {
        CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
        rect = [self.splitViewController.view convertRect:rect fromView:self.tableView];
        
        self.activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
        self.activityPopoverController.delegate = self;
        [self.activityPopoverController presentPopoverFromRect:rect inView:self.splitViewController.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
    }
}

#pragma mark - UIPopoverController delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.activityPopoverController = nil;
}

#pragma mark - IBActions

- (IBAction)switchROMTypes:(UISegmentedControl *)segmentedControl
{
    GBAVisibleROMType romType = segmentedControl.selectedSegmentIndex;
    self.romType = romType;
}

- (IBAction)searchForROMs:(UIBarButtonItem *)barButtonItem
{
    NSString *address = @"http://www.google.com/search?q=download+GBA+roms+coolrom&ie=UTF-8&oe=UTF-8&hl=en&client=safari";
    
    if (self.visibleRomType == GBAVisibleROMTypeGBC) // If ALL or GBA is selected, show GBA search results. If GBC, show GBC results
    {
        address = @"http://www.google.com/search?q=download+GBC+roms+coolrom&ie=UTF-8&oe=UTF-8&hl=en&client=safari";
    }
    
    if (![NSURLSession class]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:address]];
        
        return;
    }
    
    RSTWebViewController *webViewController = [[RSTWebViewController alloc] initWithAddress:address];
    webViewController.showDoneButton = YES;
    webViewController.downloadDelegate = self;
    webViewController.delegate = self;
    
    [[UIApplication sharedApplication] setStatusBarStyle:[webViewController preferredStatusBarStyle] animated:YES];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    [self presentViewController:navigationController animated:YES completion:NULL];
}

- (IBAction)presentSettings:(UIBarButtonItem *)barButtonItem
{
    GBASettingsViewController *settingsViewController = [[GBASettingsViewController alloc] init];
    settingsViewController.delegate = self;
    
    [[UIApplication sharedApplication] setStatusBarStyle:[settingsViewController preferredStatusBarStyle] animated:YES];
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(settingsViewController);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:navigationController animated:YES completion:NULL];
}

#pragma mark - Settings

- (void)settingsViewControllerWillDismiss:(GBASettingsViewController *)settingsViewController
{
    [self dismissedModalViewController];
}

#pragma mark - Getters/Setters

- (void)setRomType:(GBAVisibleROMType)romType
{
    self.romTypeSegmentedControl.selectedSegmentIndex = romType;
    [[NSUserDefaults standardUserDefaults] setInteger:romType forKey:@"romType"];
    
    switch (romType) {
        case GBAVisibleROMTypeAll:
            self.supportedFileExtensions = @[@"gba", @"gbc", @"gb", @"zip"];
            break;
            
        case GBAVisibleROMTypeGBA:
            self.supportedFileExtensions = @[@"gba"];
            break;
            
        case GBAVisibleROMTypeGBC:
            self.supportedFileExtensions = @[@"gb", @"gbc"];
            break;
    }
    
    _visibleRomType = romType;
}

- (void)setTheme:(GBAThemedTableViewControllerTheme)theme
{
    // Navigation controller is different each time, so we need to update theme every time we present this view controller
    /*if (_theme == theme)
    {
        return;
    }*/
    
    _theme = theme;
    
    switch (theme) {
        case GBAThemedTableViewControllerThemeOpaque:
            [self.romTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: GBA4iOS_PURPLE_COLOR} forState:UIControlStateNormal];
            [self.romTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
            break;
            
        case GBAThemedTableViewControllerThemeTranslucent:
            [self.romTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
            [self.romTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor]} forState:UIControlStateSelected];
            break;
    }
    
    [self updateTheme];
}

@end
