//
//  GBAEventDistributionDetailViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/27/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAEventDistributionDetailViewController.h"
#import "GBAAsynchronousRemoteTableViewCell.h"
#import "GBAROM_Private.h"
#import <PSPDFTextView.h>

#import "UIActionSheet+RSTAdditions.h"
#import "UIAlertView+RSTAdditions.h"

#import "GBAEvent.h"

@interface GBAEventDistributionDetailViewController ()

@property (strong, nonatomic) IBOutlet UITextView *detailTextView;

@end

@implementation GBAEventDistributionDetailViewController

- (instancetype)initWithEvent:(GBAEvent *)event
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Emulation" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"eventDistributionDetailViewController"];
    if (self)
    {
        _event = event;
        self.title = event.name;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
            
    self.detailTextView.text = self.event.eventDescription;;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contentSizeCategoryDidChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
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

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.tableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Event

- (void)startEvent
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Start this event?", @"")
                                                    message:NSLocalizedString(@"The game will restart, and any unsaved data will be lost.", @"")
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                          otherButtonTitles:NSLocalizedString(@"Start", @""), nil];
    [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 1)
        {
            NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:self.event.identifier];
            
            GBAROM *eventROM = [GBAROM romWithContentsOfFile:[uniqueEventDirectory stringByAppendingPathComponent:[self romFilename]]];
            eventROM.event = self.event;
            
            [self.delegate eventDistributionDetailViewController:self startEvent:self.event forROM:eventROM];
        }
        
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    }];
}

- (void)deleteEvent
{
    NSString *title = nil;
    
    if (self.event.endDate)
    {
        title = NSLocalizedString(@"Are you sure you want to delete this event? You can download it again at any time until the event distribution period ends.", @"");
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
    CGRect rect = [self.tableView rectForRowAtIndexPath:[self.tableView indexPathForSelectedRow]];
    
    [actionSheet showFromRect:rect inView:presentationView animated:YES selectionHandler:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
        if (buttonIndex == 0)
        {
            NSString *uniqueEventDirectory = [[self eventsDirectory] stringByAppendingPathComponent:self.event.identifier];
            [[NSFileManager defaultManager] removeItemAtPath:uniqueEventDirectory error:nil];
            
            if ([self.delegate respondsToSelector:@selector(eventDistributionDetailViewController:didDeleteEvent:)])
            {
                [self.delegate eventDistributionDetailViewController:self didDeleteEvent:self.event];
            }
            
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
        
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    }];
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return self.event.name;
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
    
    if (indexPath.row == 0)
    {
        [self startEvent];
    }
    else if (indexPath.row == 1)
    {
        [self deleteEvent];
    }
}

#pragma mark - Notifications

- (void)contentSizeCategoryDidChange:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.detailTextView.font = font;
        
        [self.tableView reloadData];
    });
}

#pragma mark - Paths

- (NSString *)eventsDirectory
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *eventsDirectory = [libraryDirectory stringByAppendingPathComponent:@"Events"];
    [[NSFileManager defaultManager] createDirectoryAtPath:eventsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    return eventsDirectory;
}

- (NSString *)romFilename
{
    NSString *name = nil;
    
    NSString *uniqueName = self.rom.uniqueName;
    
    if ([uniqueName hasPrefix:@"POKEMON EMER"])
    {
        name = @"Emerald";
    }
    else if ([uniqueName hasPrefix:@"POKEMON FIRE"])
    {
        name = @"FireRed";
    }
    else if ([uniqueName hasPrefix:@"POKEMON LEAF"])
    {
        name = @"LeafGreen";
    }
    else if ([uniqueName hasPrefix:@"POKEMON RUBY"])
    {
        name = @"Ruby";
    }
    else if ([uniqueName hasPrefix:@"POKEMON SAPP"])
    {
        name = @"Sapphire";
    }
    
    return [name stringByAppendingPathExtension:@"GBA"];
}

@end
