//
//  GBAEventDistributionViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/4/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAEventDistributionViewController.h"
#import "GBAAsynchronousRemoteTableViewCell.h"
#import "GBAEventDistributionTableViewCell.h"
#import "UIAlertView+RSTAdditions.h"
#import "GBAEventDistributionDetailViewController.h"
#import "GBAEvent.h"
#import "GBAEmulatorCore.h"
#import "GBAEventDistributionOperation.h"

#import "GBAROM_Private.h"

#import <AFNetworking/AFNetworking.h>

static void * GBADownloadProgressContext = &GBADownloadProgressContext;
static void * GBADownloadProgressTotalUnitContext = &GBADownloadProgressTotalUnitContext;

@interface GBAEventDistributionViewController () <GBAEventDistributionDetailViewControllerDelegate>

@property (strong, nonatomic) UIProgressView *downloadProgressView;
@property (strong, nonatomic) NSMutableArray *eventsArray;
@property (strong, nonatomic) NSProgress *downloadProgress;
@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) GBAROM *eventROM;
@property (strong, nonatomic) NSMutableSet *currentDownloads;
@property (strong, nonatomic) UIActivityIndicatorView *downloadingEventDistributionInfoActivityIndicatorView;

@end

@implementation GBAEventDistributionViewController

- (id)initWithROM:(GBAROM *)rom
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        _rom = rom;
        
        _currentDownloads = [NSMutableSet set];
        
        self.title = NSLocalizedString(@"Event Distribution", @"");
        
        _downloadProgress = ({
            NSProgress *progress = [[NSProgress alloc] initWithParent:nil userInfo:0];
            progress;
        });
        
        _imageCache = [[NSCache alloc] init];
        
        _eventsArray = [NSMutableArray array];
        
        [self loadLocalEvents];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    [self.tableView registerClass:[GBAAsynchronousRemoteTableViewCell class] forCellReuseIdentifier:@"ThumbnailCell"];
    [self.tableView registerClass:[GBAEventDistributionTableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"HeaderFooterViewIdentifier"];    
    
    self.downloadProgressView = ({
        UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        progressView.trackTintColor = [UIColor clearColor];
        progressView.progress = 0.0;
        progressView.alpha = 0.0;
        [self.navigationController.navigationBar addSubview:progressView];
        progressView;
    });
    
    self.downloadingEventDistributionInfoActivityIndicatorView = ({
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityIndicatorView.hidesWhenStopped = YES;
        [activityIndicatorView startAnimating];
        activityIndicatorView;
    });
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissEventDistributionViewController)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    UIBarButtonItem *activityIndicatorViewButton = [[UIBarButtonItem alloc] initWithCustomView:self.downloadingEventDistributionInfoActivityIndicatorView];
    self.navigationItem.leftBarButtonItem = activityIndicatorViewButton;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self.navigationController isBeingPresented])
    {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        }
        [self refreshEvents];
    }
    
    self.downloadProgressView.frame = CGRectMake(0,
                                                 CGRectGetHeight(self.navigationController.navigationBar.bounds) - CGRectGetHeight(self.downloadProgressView.bounds),
                                                 CGRectGetWidth(self.navigationController.navigationBar.bounds),
                                                 CGRectGetHeight(self.downloadProgressView.bounds));
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Refresh Events

- (void)loadLocalEvents
{
    NSMutableArray *events = [NSMutableArray array];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:[self eventsDirectory]]
                                                             includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler:^BOOL(NSURL *url, NSError *error)
                                         {
                                             NSLog(@"[Error] %@ (%@)", error, url);
                                             return YES;
                                         }];
    
    for (NSURL *fileURL in enumerator)
    {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        
        if (![isDirectory boolValue])
        {
            if (![filename isEqualToString:@"info.gbaevent"])
            {
                continue;
            }
            
            GBAEvent *event = [GBAEvent eventWithContentsOfFile:[fileURL path]];
            
            NSString *romPath = [[fileURL.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[self remoteROMFilename]];
            
            if (![event supportsGame:[self eventSupportedGame]] || ![[NSFileManager defaultManager] fileExistsAtPath:romPath])
            {
                continue;
            }
                        
            [events addObject:event];
        }
    }
    
    self.eventsArray = events;
}

- (void)refreshEvents
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.downloadingEventDistributionInfoActivityIndicatorView startAnimating];
    });
    
    GBAEventDistributionOperation *eventDistributionOperation = [GBAEventDistributionOperation new];
    [eventDistributionOperation checkForEventsWithCompletion:^(NSArray *events, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.downloadingEventDistributionInfoActivityIndicatorView stopAnimating];
        });
        
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithError:error];
                [alert show];
            });
            return;
        }
        
        NSArray *localEvents = [self.eventsArray copy];
        NSMutableArray *modifiedEvents = [NSMutableArray array];
        
        [modifiedEvents addObjectsFromArray:localEvents];
        
        for (GBAEvent *event in events)
        {
            if (![event supportsGame:[self eventSupportedGame]])
            {
                continue;
            }
            
            if ([event isExpired])
            {
                continue;
            }
            
            if ([localEvents containsObject:event])
            {
                continue;
            }
            
            [modifiedEvents addObject:event];
        }
        
        self.eventsArray = modifiedEvents;
        
        [self updateTableViewWithAnimation];
        
    }];
}

- (void)updateSectionForEvent:(GBAEvent *)event
{
    NSInteger section = [self.eventsArray indexOfObject:event];
    section++; // Compensate for empty section at top
    
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:section]] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)updateTableViewWithAnimation
{
    NSUInteger currentNumberOfSections = self.tableView.numberOfSections;
    
    [self.tableView beginUpdates];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, currentNumberOfSections)] withRowAnimation:UITableViewRowAnimationFade];
    
    if ([self.eventsArray count] > currentNumberOfSections - 1)
    {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(currentNumberOfSections, self.eventsArray.count - (currentNumberOfSections - 1))] withRowAnimation:UITableViewRowAnimationFade];
    }
    
    [self.tableView endUpdates];
}

#pragma mark - Download Events

- (void)downloadEvent:(GBAEvent *)event
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *identifier = event.identifier;
    NSURL *URL = [self URLForFileWithName:[self remoteROMFilename] identifier:identifier];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSProgress *progress = nil;
    __block NSProgress *strongReferenceProgress = nil;
    
    // iOS 8 crashes when trying to figure out destinationURL in destination block
    NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:identifier];
    [[NSFileManager defaultManager] createDirectoryAtPath:uniqueEventDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSURL *destinationURL = [NSURL fileURLWithPath:[uniqueEventDirectory stringByAppendingPathComponent:[self remoteROMFilename]]];
    
    __strong NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:&progress destination:^NSURL *(NSURL *targetPath, NSURLResponse *response)
    {
        return destinationURL;
        
    } completionHandler:^(NSURLResponse *response, NSURL *fileURL, NSError *error)
                                                       {
                                                           [self.currentDownloads removeObject:event];
                                                           
                                                           if (error)
                                                           {
                                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                                   UIAlertView *alert = [[UIAlertView alloc] initWithError:error];
                                                                   [alert show];
                                                               });
                                                               
                                                               strongReferenceProgress.completedUnitCount = strongReferenceProgress.totalUnitCount;
                                                               
                                                               [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                                               
                                                               [self updateSectionForEvent:event]; // Has to go after removing file
                                                               return;
                                                           }
                                                           
                                                           NSString *eventInfoPath = [[destinationURL.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"info.gbaevent"];
                                                           [event writeToFile:eventInfoPath];
                                                           [self updateSectionForEvent:event]; // Has to go after writing to file
                                                       }];
    
    [progress addObserver:self forKeyPath:@"totalUnitCount" options:NSKeyValueObservingOptionNew context:GBADownloadProgressTotalUnitContext];
    [progress addObserver:self forKeyPath:@"completedUnitCount" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:GBADownloadProgressContext];
    
    strongReferenceProgress = progress;
    
    [downloadTask resume];
    
    [self.currentDownloads addObject:event];
    [self updateSectionForEvent:event];
    
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

#pragma mark - Event

- (void)finishCurrentEvent
{
    [[GBAEmulatorCore sharedCore] setCustomSavePath:nil];
    
    self.emulationViewController.rom = self.rom;
    
    // Let the ROM run a little bit before we freeze it
    double delayInSeconds = 0.3;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.emulationViewController pauseEmulation];
        [self.emulationViewController refreshLayout];
    });
    
    if ([self.delegate respondsToSelector:@selector(eventDistributionViewController:didFinishEvent:)])
    {
        [self.delegate eventDistributionViewController:self didFinishEvent:self.eventROM];
    }
}

#pragma mark - Dismissal

- (void)dismissEventDistributionViewController
{
    if ([self.delegate respondsToSelector:@selector(eventDistributionViewControllerWillDismiss:)])
    {
        [self.delegate eventDistributionViewControllerWillDismiss:self];
    }
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.eventsArray.count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return 0;
    }
    
    if (indexPath.row == 0)
    {
        return 216;
    }
    
    return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 0;
    }
    
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return nil;
    }
    
    GBAEvent *event = [self eventForSection:section];
    return event.name;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"Events unlock certain features that are not normally in the game. However, they can only be completed once per save file.", @"");
    }
    
    GBAEvent *event = [self eventForSection:section];
    return event.blurb;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAEvent *event = [self eventForSection:indexPath.section];
    
    if (indexPath.row > 0)
    {
        GBAEventDistributionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
        
        NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:event.identifier];
        NSString *eventFilepath = [uniqueEventDirectory stringByAppendingPathComponent:[self remoteROMFilename]];
                
        if ([self.currentDownloads containsObject:event])
        {
            cell.downloadState = GBAEventDownloadStateDownloading;
        }
        else if ([[NSFileManager defaultManager] fileExistsAtPath:eventFilepath])
        {
            cell.downloadState = GBAEventDownloadStateDownloaded;
        }
        else
        {
            cell.downloadState = GBAEventDownloadStateNotDownloaded;
        }
        
        NSDate *endDate = event.endDate;
        
        if (endDate && [endDate isKindOfClass:[NSDate class]])
        {
            cell.endDate = endDate;
        }
        
        return cell;
    }
    
    static NSString *CellIdentifier = @"ThumbnailCell";
    GBAAsynchronousRemoteTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:indexPath.section];
    
    cell.imageCache = self.imageCache;
    
    NSString *imageFilename = [self remoteThumbnailFilename];

    cell.imageURL = [self URLForFileWithName:imageFilename identifier:event.identifier];
    
    cell.separatorInset = UIEdgeInsetsZero;
    
    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAEvent *event = [self eventForSection:indexPath.section];
    
    NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:event.identifier];
    NSString *eventFilepath = [uniqueEventDirectory stringByAppendingPathComponent:[self remoteROMFilename]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:eventFilepath])
    {
        GBAEventDistributionDetailViewController *eventDistributionDetailViewController = [[GBAEventDistributionDetailViewController alloc] initWithEvent:event];
        eventDistributionDetailViewController.delegate = self;
        eventDistributionDetailViewController.imageCache = self.imageCache;
        eventDistributionDetailViewController.rom = self.rom;
        
        GBAAsynchronousRemoteTableViewCell *cell = (GBAAsynchronousRemoteTableViewCell *)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:indexPath.section]];
        eventDistributionDetailViewController.imageURL = cell.imageURL;
        
        [self.navigationController pushViewController:eventDistributionDetailViewController animated:YES];
    }
    else
    {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
        
        if ([self.currentDownloads containsObject:event])
        {
            return;
        }
        
        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to download the “%@” event?", @""), event.name];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Download", @""), nil];
        [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 0)
            {
                return;
            }
            
            [self downloadEvent:event];
        }];
    }
}

#pragma mark - GBAEventDistributionDetailViewControllerDelegate


- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController startEvent:(GBAEvent *)event forROM:(GBAROM *)rom
{
    [[GBAEmulatorCore sharedCore] setCustomSavePath:self.rom.saveFileFilepath];
    
    self.eventROM = rom;

    self.emulationViewController.rom = self.eventROM;
    
    if ([self.delegate respondsToSelector:@selector(eventDistributionViewController:willStartEvent:)])
    {
        [self.delegate eventDistributionViewController:self willStartEvent:self.eventROM];
    }
    
    [self dismissEventDistributionViewController];
}

- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController didDeleteEvent:(GBAEvent *)event
{
    [self updateSectionForEvent:event];
}

#pragma mark - Paths

- (NSString *)eventsDirectory
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *eventsDirectory = [libraryDirectory stringByAppendingPathComponent:@"Events"];
    [[NSFileManager defaultManager] createDirectoryAtPath:eventsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    return eventsDirectory;
}

#pragma mark - Helper Methods

- (GBAEvent *)eventForSection:(NSInteger)section
{
    section = section - 1;
    
    return self.eventsArray[section];
}

- (NSURL *)URLForFileWithName:(NSString *)name identifier:(NSString *)identifier
{
    NSString *address = [GBAEventDistributionRootAddress stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", identifier, name]];
    return [NSURL URLWithString:address];
}

- (NSString *)remoteROMFilename
{
    return [[self remoteROMName] stringByAppendingPathExtension:@"GBA"];
}

- (NSString *)remoteThumbnailFilename
{
    return [[self remoteROMName] stringByAppendingPathExtension:@"PNG"];
}

- (NSString *)remoteROMName
{
    NSString *uniqueName = self.rom.uniqueName;
    
    if ([uniqueName hasPrefix:@"POKEMON EMER"])
    {
        return @"Emerald";
    }
    else if ([uniqueName hasPrefix:@"POKEMON FIRE"])
    {
        return @"FireRed";
    }
    else if ([uniqueName hasPrefix:@"POKEMON LEAF"])
    {
        return @"LeafGreen";
    }
    else if ([uniqueName hasPrefix:@"POKEMON RUBY"])
    {
        return @"Ruby";
    }
    else if ([uniqueName hasPrefix:@"POKEMON SAPP"])
    {
        return @"Sapphire";
    }
    
    return @"";
}

- (GBAEventSupportedGame)eventSupportedGame
{
    NSString *uniqueName = self.rom.uniqueName;
    
    if ([uniqueName hasPrefix:@"POKEMON EMER"])
    {
        return GBAEventSupportedGameEmerald;
    }
    else if ([uniqueName hasPrefix:@"POKEMON FIRE"])
    {
        return GBAEventSupportedGameFireRed;
    }
    else if ([uniqueName hasPrefix:@"POKEMON LEAF"])
    {
        return GBAEventSupportedGameLeafGreen;
    }
    else if ([uniqueName hasPrefix:@"POKEMON RUBY"])
    {
        return GBAEventSupportedGameRuby;
    }
    else if ([uniqueName hasPrefix:@"POKEMON SAPP"])
    {
        return GBAEventSupportedGameSapphire;
    }
    
    return GBAEventSupportedGameNone;
}

- (NSString *)downloadedEventsPath
{
    return [[self eventsDirectory] stringByAppendingPathComponent:@"downloadedEvents.plist"];
}

@end
