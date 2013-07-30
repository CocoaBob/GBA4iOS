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

#import <RSTWebViewController.h>
#import <UIAlertView+RSTAdditions.h>

#import <SSZipArchive/minizip/SSZipArchive.h>

#define LEGAL_NOTICE_ALERT_TAG 15
#define NAME_ROM_ALERT_TAG 17
#define DELETE_ROM_ALERT_TAG 2

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

@property (copy, nonatomic) RSTWebViewControllerStartDownloadBlock startDownloadBlock;
@property (weak, nonatomic) NSURLSessionDownloadTask *tempDownloadTask;

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
    
    GBAROMType romType = [[NSUserDefaults standardUserDefaults] integerForKey:@"romType"];
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
                                                    message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Download", @""), nil];
    alert.tag = LEGAL_NOTICE_ALERT_TAG;
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert show];
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
        //ELog(error);
        return;
    }
    
    [fileManager moveItemAtURL:fileURL toURL:destinationURL error:&error];
    
    DLog(@"Download Complete: %@", filename);
    
    if (error)
    {
        //ELog(error);
    }
}

- (void)webViewController:(RSTWebViewController *)webViewController downloadTask:(NSURLSessionDownloadTask *)downloadTask didCompleteDownloadWithError:(NSError *)error
{
    if (error)
    {
        //ELog(error);
        
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
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    return cell;
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
        //ELog(error);
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
        //ELog(error);
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
        //ELog(error);
    }
}

#pragma mark - UIAlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == LEGAL_NOTICE_ALERT_TAG)
    {
        if (buttonIndex == 1)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ROM Name:", @"")
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Save", @""), nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            alert.tag = NAME_ROM_ALERT_TAG;
            
            [alert show];
        }
        else
        {
            [self cancelDownload];
        }
    }
    else if (alertView.tag == NAME_ROM_ALERT_TAG)
    {
        if (buttonIndex == 1)
        {
            NSString *filename = [[alertView textFieldAtIndex:0] text];
            [self startDownloadWithFilename:filename];
        }
        else
        {
            [self cancelDownload];
        }
    }
    else if (alertView.tag == DELETE_ROM_ALERT_TAG)
    {
    }
}

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView // Not working in iOS 7, hoping for fix http://openradar.appspot.com/14387317
{
    //UITextField *textField = [alertView textFieldAtIndex:0];
    //return [textField.text length] > 0;
    
    return YES;
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
    
    GBAEmulationViewController *emulationViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"emulationViewController"];
    emulationViewController.romFilepath = filepath;
    emulationViewController.skinFilepath = [[self GBASkinsDirectory] stringByAppendingPathComponent:@"Default"];
    
    if ([emulationViewController respondsToSelector:@selector(setTransitioningDelegate:)])
    {
        emulationViewController.transitioningDelegate = self;
        emulationViewController.modalPresentationStyle = UIModalPresentationCustom;
    }
    
    [self presentViewController:emulationViewController animated:YES completion:NULL];
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Test" message:@"AWESOME" cancelButtonTitle:@"Cancel" otherButtonTitles:@"SWEET", @"COOL", nil];
        [alert showWithCompletionHandler:^(UIAlertView *alertView, NSInteger buttonIndex)
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

#pragma mark - Presenting Emulation View Controller

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return [[GBAPresentEmulationViewControllerAnimator alloc] init];
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




@end
