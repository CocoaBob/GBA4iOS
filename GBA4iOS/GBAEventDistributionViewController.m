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
#import "NSDate+Comparing.h"
#import "UIAlertView+RSTAdditions.h"
#import "GBAEventDictionary.h"
#import "GBAEventDistributionDetailViewController.h"

#import "GBAROM_Private.h"

#import <AFNetworking/AFNetworking.h>

#define EVENT_DISTRIBUTION_ROOT_ADDRESS @"http://gba4iosapp.com/eventdistribution/"

NSString *const GBAEventsKey = @"events";
NSString *const GBAEventNameKey = @"name";
NSString *const GBAEventDescriptionKey = @"description";
NSString *const GBAEventDetailedDescriptionKey = @"detailedDescription";
NSString *const GBAEventIdentifierKey = @"identifier";
NSString *const GBAEventGames = @"games";
NSString *const GBAEventEndDate = @"endDate";


static void * GBADownloadProgressContext = &GBADownloadProgressContext;
static void * GBADownloadProgressTotalUnitContext = &GBADownloadProgressTotalUnitContext;

@interface GBAEventDistributionViewController () <GBAEventDistributionDetailViewControllerDelegate>

@property (strong, nonatomic) UIProgressView *downloadProgressView;
@property (strong, nonatomic) NSDictionary *eventsDictionary;
@property (strong, nonatomic) NSProgress *downloadProgress;
@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) GBAROM *eventROM;
@property (strong, nonatomic) NSMutableSet *currentDownloads;

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
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissEventDistributionViewController)];
    self.navigationItem.rightBarButtonItem = doneButton;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self.navigationController isBeingPresented])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        [self refreshEvents];
    }
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

- (void)refreshEvents
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *address = [EVENT_DISTRIBUTION_ROOT_ADDRESS stringByAppendingPathComponent:@"root.json"];
    NSURL *URL = [NSURL URLWithString:address];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, NSDictionary *jsonObject, NSError *error) {
        
        NSMutableDictionary *responseObject = [jsonObject mutableCopy];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            return;
        }
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"MM/dd/yyyy"];
        
        NSMutableArray *modifiedEvents = [responseObject[GBAEventsKey] mutableCopy];
        
        [responseObject[GBAEventsKey] enumerateObjectsUsingBlock:^(NSDictionary *event, NSUInteger index, BOOL *stop) {
            NSArray *games = event[GBAEventGames];
            
            if (![games containsObject:[self remoteROMName]])
            {
                [modifiedEvents removeObject:event];
                return;
            }
            
            NSString *dateString = event[GBAEventEndDate];
            
            if (dateString == nil)
            {
                return;
            }
            
            NSDate *endDate = [dateFormatter dateFromString:dateString];
            
            if (endDate == nil)
            {
                return;
            }
            
            if ([[NSDate date] daysUntilDate:endDate] < 0)
            {
                [modifiedEvents removeObject:event];
            }
            else
            {
                NSMutableDictionary *mutableEvent = [event mutableCopy];
                mutableEvent[GBAEventEndDate] = endDate;
                [modifiedEvents replaceObjectAtIndex:index withObject:mutableEvent];
            }
        }];
        
        responseObject[GBAEventsKey] = modifiedEvents;
        
        self.eventsDictionary = responseObject;
        
        [UIView transitionWithView:self.tableView duration:0.5f options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self.tableView reloadData];
        } completion:NULL];
        
    }];
    
    [dataTask resume];
}

- (void)updateSectionForEventDictionary:(NSDictionary *)dictionary
{
    NSArray *events = self.eventsDictionary[GBAEventsKey];
    
    NSInteger section = [events indexOfObject:dictionary];
    section++; // Compensate for empty section at top
    
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:section]] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - Download Events

- (void)downloadEventForDictionary:(NSDictionary *)dictionary
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *identifier = dictionary[GBAEventIdentifierKey];
    NSURL *URL = [self URLForFileWithName:[self remoteROMFilename] identifier:identifier];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSProgress *progress = nil;
    
    __strong NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:&progress destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:identifier];
        [[NSFileManager defaultManager] createDirectoryAtPath:uniqueEventDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        return [NSURL fileURLWithPath:[uniqueEventDirectory stringByAppendingPathComponent:[self remoteROMFilename]]];
        
    } completionHandler:^(NSURLResponse *response, NSURL *fileURL, NSError *error)
                                                       {
                                                           
                                                           if (error)
                                                           {
                                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                                   UIAlertView *alert = [[UIAlertView alloc] initWithError:error];
                                                                   [alert show];
                                                               });
                                                               
                                                               progress.completedUnitCount = progress.totalUnitCount;
                                                               
                                                               [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                                               return;
                                                           }
                                                           
                                                           [self.currentDownloads removeObject:dictionary[GBAEventIdentifierKey]];
                                                           [self updateSectionForEventDictionary:dictionary];
                                                       }];
    
    [progress addObserver:self forKeyPath:@"totalUnitCount" options:NSKeyValueObservingOptionNew context:GBADownloadProgressTotalUnitContext];
    [progress addObserver:self forKeyPath:@"completedUnitCount" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:GBADownloadProgressContext];
    
    [downloadTask resume];
    
    [self.currentDownloads addObject:dictionary[GBAEventIdentifierKey]];
    [self updateSectionForEventDictionary:dictionary];
    
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
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.eventROM.saveFileFilepath isDirectory:nil])
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.rom.saveFileFilepath isDirectory:nil])
        {
            [[NSFileManager defaultManager] replaceItemAtURL:[NSURL fileURLWithPath:self.rom.saveFileFilepath] withItemAtURL:[NSURL fileURLWithPath:self.eventROM.saveFileFilepath] backupItemName:nil options:0 resultingItemURL:nil error:nil];
        }
        else
        {
            [[NSFileManager defaultManager] copyItemAtPath:self.eventROM.saveFileFilepath toPath:self.rom.saveFileFilepath error:nil];
        }
    }
    
    if ([self.eventROM eventCompleted])
    {
        // Remove event rom directory
        [[NSFileManager defaultManager] removeItemAtPath:[self.eventROM.filepath stringByDeletingLastPathComponent] error:nil];
    }
    
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
    NSArray *events = self.eventsDictionary[GBAEventsKey];
    return events.count + 1;
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
    
    NSDictionary *event = [self dictionaryForSection:section];
    return event[GBAEventNameKey];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"Events unlock certain features that are not normally in the game. However, they can only be used once per save file.", @"");
    }
    
    NSDictionary *event = [self dictionaryForSection:section];
    return event[GBAEventDescriptionKey];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *dictionary = [self dictionaryForSection:indexPath.section];
    
    if (indexPath.row > 0)
    {
        GBAEventDistributionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
        
        NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:dictionary[GBAEventIdentifierKey]];
        
        if ([self.currentDownloads containsObject:dictionary[GBAEventIdentifierKey]])
        {
            cell.downloadState = GBAEventDownloadStateDownloading;
        }
        else if ([[NSFileManager defaultManager] fileExistsAtPath:uniqueEventDirectory isDirectory:nil])
        {
            cell.downloadState = GBAEventDownloadStateDownloaded;
        }
        else
        {
            cell.downloadState = GBAEventDownloadStateNotDownloaded;
        }
        
        NSDate *endDate = dictionary[GBAEventEndDate];
        
        if (endDate && [endDate isKindOfClass:[NSDate class]])
        {
            cell.endDate = endDate;
        }
        
        return cell;
    }
    
    static NSString *CellIdentifier = @"ThumbnailCell";
    GBAAsynchronousRemoteTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:indexPath.section];
    
    NSString *identifier = dictionary[GBAEventIdentifierKey];
    
    cell.imageCache = self.imageCache;
    
    NSString *imageFilename = [self remoteThumbnailFilename];

    cell.imageURL = [self URLForFileWithName:imageFilename identifier:identifier];
    
    cell.separatorInset = UIEdgeInsetsZero;
    
    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *eventDictionary = [self dictionaryForSection:indexPath.section];
    
    NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:eventDictionary[GBAEventIdentifierKey]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:uniqueEventDirectory])
    {
        GBAEventDistributionDetailViewController *eventDistributionDetailViewController = [[GBAEventDistributionDetailViewController alloc] initWithEventDictionary:eventDictionary];
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
        
        if ([self.currentDownloads containsObject:eventDictionary[GBAEventIdentifierKey]])
        {
            return;
        }
        
        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to download the “%@” event?", @""), eventDictionary[GBAEventNameKey]];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Download", @""), nil];
        [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 0)
            {
                return;
            }
            
            [self downloadEventForDictionary:eventDictionary];
        }];
    }
}

#pragma mark - GBAEventDistributionDetailViewControllerDelegate

- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController startEventROM:(GBAROM *)eventROM
{
    self.eventROM = eventROM;
    self.eventROM.event = YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.rom.saveFileFilepath isDirectory:nil])
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.eventROM.saveFileFilepath isDirectory:nil])
        {
            [[NSFileManager defaultManager] replaceItemAtURL:[NSURL fileURLWithPath:self.eventROM.saveFileFilepath] withItemAtURL:[NSURL fileURLWithPath:self.rom.saveFileFilepath] backupItemName:nil options:0 resultingItemURL:nil error:nil];
        }
        else
        {
            [[NSFileManager defaultManager] copyItemAtPath:self.rom.saveFileFilepath toPath:self.eventROM.saveFileFilepath error:nil];
        }
    }
    
    self.emulationViewController.rom = self.eventROM;
    
    if ([self.delegate respondsToSelector:@selector(eventDistributionViewController:willStartEvent:)])
    {
        [self.delegate eventDistributionViewController:self willStartEvent:self.eventROM];
    }
    
    [self dismissEventDistributionViewController];
}

- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController didDeleteEventDictionary:(NSDictionary *)dictionary
{
    [self updateSectionForEventDictionary:dictionary];
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

- (NSDictionary *)dictionaryForSection:(NSInteger)section
{
    section = section - 1;
    
    NSArray *events = self.eventsDictionary[GBAEventsKey];
    return events[section];
}

- (NSURL *)URLForFileWithName:(NSString *)name identifier:(NSString *)identifier
{
    NSString *address = [EVENT_DISTRIBUTION_ROOT_ADDRESS stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", identifier, name]];
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

@end
