//
//  GBAControllerSkinDownloadGroupsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/6/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDownloadViewController.h"
#import "GBAAsynchronousRemoteTableViewCell.h"
#import "GBAControllerSkinGroup.h"
#import "GBAControllerSkinDownloadController.h"
#import "GBAControllerSkinGroupViewController.h"

#import "UIAlertView+RSTAdditions.h"
#import "UITableViewController+ControllerSkins.h"

static void *GBAControllerSkinDownloadViewControllerContext = &GBAControllerSkinDownloadViewControllerContext;

@interface GBAControllerSkinDownloadViewController ()

@property (copy, nonatomic) NSArray *groups;
@property (strong, nonatomic) UIActivityIndicatorView *refreshingActivityIndicatorView;
@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) GBAControllerSkinDownloadController *downloadController;
@property (strong, nonatomic) UIProgressView *progressView;

@end

@implementation GBAControllerSkinDownloadViewController

- (instancetype)initWithControllerSkinType:(GBAControllerSkinType)controllerSkinType
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        self.title = NSLocalizedString(@"Download Skins", @"");
        
        _controllerSkinType = controllerSkinType;
        _imageCache = [[NSCache alloc] init];
        
        _downloadController = [GBAControllerSkinDownloadController new];
        [_downloadController.progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionNew context:GBAControllerSkinDownloadViewControllerContext];
        
        _refreshingActivityIndicatorView = ({
            UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicatorView.hidesWhenStopped = YES;
            [activityIndicatorView startAnimating];
            activityIndicatorView;
        });
        
        _progressView = ({
            UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
            progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
            progressView.trackTintColor = [UIColor clearColor];
            progressView.progress = 0.0;
            progressView.alpha = 0.0;
            progressView;
        });
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismiss:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    UIBarButtonItem *activityIndicatorViewButton = [[UIBarButtonItem alloc] initWithCustomView:self.refreshingActivityIndicatorView];
    self.navigationItem.leftBarButtonItem = activityIndicatorViewButton;
    
    self.progressView.frame = CGRectMake(0,
                                    CGRectGetHeight(self.navigationController.navigationBar.bounds) - CGRectGetHeight(self.progressView.bounds),
                                    CGRectGetWidth(self.navigationController.navigationBar.bounds),
                                    CGRectGetHeight(self.progressView.bounds));
    [self.navigationController.navigationBar addSubview:self.progressView];
    
    [self.tableView registerClass:[GBAAsynchronousRemoteTableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self.groups count] == 0)
    {
        self.groups = [NSKeyedUnarchiver unarchiveObjectWithFile:[self cachedResponsePath]];
        
        [self updateRowHeightsForDisplayingControllerSkinsWithType:self.controllerSkinType];
        
        [self refreshControllerSkinGroups];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Refreshing Controller Skin Groups -

- (void)refreshControllerSkinGroups
{
    [self.downloadController retrieveControllerSkinGroupsWithCompletion:^(NSArray *groups, NSError *error) {
        
        [self.refreshingActivityIndicatorView stopAnimating];
        
        if (error)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithError:error];
            [alert show];
            
            return;
        }
        
        NSMutableArray *filteredGroups = [NSMutableArray array];
        
        for (GBAControllerSkinGroup *group in groups)
        {
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
            
            [group filterSkinsForDeviceType:deviceType controllerSkinType:self.controllerSkinType];
            
            if ([group.skins count] > 0)
            {
                [filteredGroups addObject:group];
            }
        }
        
        if ([self.groups isEqualToArray:filteredGroups])
        {
            return;
        }
        
        self.groups = filteredGroups;
        
        [self updateTableViewWithAnimation];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [NSKeyedArchiver archiveRootObject:filteredGroups toFile:[self cachedResponsePath]];
        });
        
    }];
}

- (void)updateTableViewWithAnimation
{
    NSInteger currentNumberOfSections = self.tableView.numberOfSections;
    
    [self.tableView beginUpdates];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, MIN(currentNumberOfSections - 1, (long)self.groups.count))] withRowAnimation:UITableViewRowAnimationFade];
    
    if ((int)[self.groups count] > currentNumberOfSections - 1)
    {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(currentNumberOfSections, self.groups.count - (currentNumberOfSections - 1))] withRowAnimation:UITableViewRowAnimationFade];
    }
    
    if ((int)[self.groups count] < currentNumberOfSections - 1)
    {
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.groups.count + 1, (currentNumberOfSections - 1) - self.groups.count)] withRowAnimation:UITableViewRowAnimationFade];
    }
    
    [self.tableView endUpdates];
}

#pragma mark - Dismissal -

- (void)dismiss:(UIBarButtonItem *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Download Progress -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != GBAControllerSkinDownloadViewControllerContext)
    {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    if ([keyPath isEqualToString:@"fractionCompleted"])
    {
        NSProgress *progress = object;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Disable the "Done" button until the download is compeleted; i.e. fractionCompleted = 0
            if (progress.fractionCompleted != 0) {
                self.navigationItem.rightBarButtonItem.enabled = false;
            } else {
                self.navigationItem.rightBarButtonItem.enabled = true;
            }
            
            if (progress.fractionCompleted > 0)
            {
                if (self.progressView.alpha == 0)
                {
                    [UIView animateWithDuration:0.4 animations:^{
                        [self.progressView setAlpha:1.0];
                    }];
                }
            }
            else
            {
                if (self.progressView.alpha > 0)
                {
                    [UIView animateWithDuration:0.4 animations:^{
                        [self.progressView setAlpha:0.0];
                    } completion:^(BOOL finished) {
                        [self.progressView setProgress:0.0];
                    }];
                }
            }
            
            if (self.progressView.alpha > 0)
            {
                self.progressView.progress = progress.fractionCompleted;
            }
            
        });
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.groups count] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 0;
    }
    
    GBAControllerSkinGroup *group = self.groups[section - 1];
    NSArray *imageURLs = group.imageURLs;
    
    return [imageURLs count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return nil;
    }
    
    GBAControllerSkinGroup *group = self.groups[section - 1];
    return group.name;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"You can import other .gbaskin or .gbcskin files via iTunes, or by downloading them in Safari and opening in GBA4iOS.", @"");
    }
    
    GBAControllerSkinGroup *group = self.groups[section - 1];
    return group.blurb;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAAsynchronousRemoteTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    GBAControllerSkinGroup *group = self.groups[indexPath.section - 1];
    cell.imageURL = group.imageURLs[indexPath.row];
    cell.imageCache = self.imageCache;
    
    cell.separatorInset = UIEdgeInsetsZero;
    // Configure the cell...
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBAControllerSkinGroup *group = self.groups[indexPath.section - 1];
    
    GBAControllerSkinGroupViewController *groupViewController = [[GBAControllerSkinGroupViewController alloc] initWithControllerSkinGroup:group];
    groupViewController.downloadController = self.downloadController;
    [self.navigationController pushViewController:groupViewController animated:YES];
}

#pragma mark - Filepaths

- (NSString *)cachedResponsePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *cachedSkinsResponsePath = nil;
    
    if (self.controllerSkinType == GBAControllerSkinTypeGBA)
    {
        cachedSkinsResponsePath = [cachesDirectory stringByAppendingPathComponent:@"controllerSkinsResponse-gba.plist"];
    }
    else
    {
        cachedSkinsResponsePath = [cachesDirectory stringByAppendingPathComponent:@"controllerSkinsResponse-gbc.plist"];
    }
    
    return cachedSkinsResponsePath;
}

@end
