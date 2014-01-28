//
//  GBAEventDistributionDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/27/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAEventDistributionDetailViewController.h"
#import "GBAEventDictionary.h"
#import "GBAAsynchronousRemoteTableViewCell.h"
#import "GBAROM_Private.h"
#import <PSPDFTextView.h>

#import "UIActionSheet+RSTAdditions.h"

@interface GBAEventDistributionDetailViewController ()

@property (copy, nonatomic) NSDictionary *eventDictionary;
@property (strong, nonatomic) IBOutlet UITextView *detailTextView;

@end

@implementation GBAEventDistributionDetailViewController

- (instancetype)initWithEventDictionary:(NSDictionary *)dictionary
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"eventDistributionDetailViewController"];
    if (self)
    {
        _eventDictionary = [dictionary copy];
        
        self.title = dictionary[GBAEventNameKey];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSString *detailedDescription = self.eventDictionary[GBAEventDetailedDescriptionKey];
        
    self.detailTextView.text = detailedDescription;
    
    UIBarButtonItem *startButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Start", @"") style:UIBarButtonItemStyleDone target:self action:@selector(startEvent:)];
    self.navigationItem.rightBarButtonItem = startButton;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.detailTextView.contentSize = self.detailTextView.bounds.size;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.tableView reloadData];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    self.detailTextView.contentSize = self.detailTextView.bounds.size;
}


#pragma mark - Event

- (void)startEvent:(UIBarButtonItem *)barButtonItem
{
    NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:self.eventDictionary[GBAEventIdentifierKey]];
    
    GBAROM *eventROM = [GBAROM romWithContentsOfFile:[uniqueEventDirectory stringByAppendingPathComponent:[self remoteROMFilename]]];
    eventROM.event = YES;
    
    [self.delegate eventDistributionDetailViewController:self startEventROM:eventROM];
}

- (void)deleteEvent
{
    NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:self.eventDictionary[GBAEventIdentifierKey]];
    [[NSFileManager defaultManager] removeItemAtPath:uniqueEventDirectory error:nil];
    
    if ([self.delegate respondsToSelector:@selector(eventDistributionDetailViewController:didDeleteEventDictionary:)])
    {
        [self.delegate eventDistributionDetailViewController:self didDeleteEventDictionary:self.eventDictionary];
    }
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return self.eventDictionary[GBAEventNameKey];
    }
    
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 1)
    {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    
    CGSize textViewSize = [self.detailTextView sizeThatFits:CGSizeMake(CGRectGetWidth(self.view.bounds) - 20, FLT_MAX)];
    
    return ceilf(textViewSize.height);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if (indexPath.section == 0)
    {
        if ([(GBAAsynchronousRemoteTableViewCell *)cell imageURL] == nil)
        {
            [(GBAAsynchronousRemoteTableViewCell *)cell setImageCache:self.imageCache];
            [(GBAAsynchronousRemoteTableViewCell *)cell setImageURL:self.imageURL];
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 2)
    {
        return;
    }
    
    NSString *title = nil;
    
    if (self.eventDictionary[GBAEventEndDate])
    {
        title = NSLocalizedString(@"Are you sure you want to delete this event? You can download it again at any time before it expires.", @"");
    }
    else
    {
        title = NSLocalizedString(@"Are you sure you want to delete this event? You can download it again at any time.", @"");
    }
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                             delegate:nil
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                               destructiveButtonTitle:NSLocalizedString(@"Delete Event", @"")
                                                    otherButtonTitles:nil];
    UIView *presentationView = self.view;
    CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    [actionSheet showFromRect:rect inView:presentationView animated:YES selectionHandler:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            [self deleteEvent];
        }
        
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    }];
}

#pragma mark - Paths

- (NSString *)eventsDirectory
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *eventsDirectory = [libraryDirectory stringByAppendingPathComponent:@"Events"];
    [[NSFileManager defaultManager] createDirectoryAtPath:eventsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    return eventsDirectory;
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
