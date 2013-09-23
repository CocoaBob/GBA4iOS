//
//  GBASaveStateViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASaveStateViewController.h"
#import "GBASaveStateTableViewCell.h"

#if !(TARGET_IPHONE_SIMULATOR)
#import "GBAEmulatorCore.h"
#endif

#import <UIAlertView+RSTAdditions.h>
#import <RSTActionSheet/UIActionSheet+RSTAdditions.h>

#define INFO_PLIST_PATH [self.saveStateDirectory stringByAppendingPathComponent:@"info.plist"]

@interface GBASaveStateViewController ()

@property (copy, nonatomic) NSString *saveStateDirectory;
@property (strong, nonatomic) NSMutableArray *saveStateArray;

@end

@implementation GBASaveStateViewController

- (id)initWithSaveStateDirectory:(NSString *)directory mode:(GBASaveStateViewControllerMode)mode
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)
    {
        _mode = mode;
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        
        _saveStateDirectory = [directory copy];
        _saveStateArray = [NSMutableArray arrayWithContentsOfFile:INFO_PLIST_PATH];
        
        if (_saveStateArray == nil)
        {
            _saveStateArray = [[NSMutableArray alloc] init];
            
            // Autosave and General
            [_saveStateArray addObject:[NSArray array]];
            [_saveStateArray addObject:[NSArray array]];
            [_saveStateArray addObject:[NSArray array]];
        }
        
        NSString *autosaveFilepath = [_saveStateDirectory stringByAppendingPathComponent:@"autosave.sgm"];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:autosaveFilepath error:nil];
        
        if (attributes)
        {
            // In case we've added an autosave, we need to add it to the array. Use the file modification date as the date
            NSDate *date = [attributes fileModificationDate];
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            [dateFormatter setDateStyle:NSDateFormatterLongStyle];
            
            NSString *name = [dateFormatter stringFromDate:date];
            
            NSMutableArray *array = [_saveStateArray[0] mutableCopy];
            array[0] = @{@"filename": @"autosave.sgm", @"name": name, @"protected": @YES};
            _saveStateArray[0] = array;
        }
        else
        {
            // Yes, we re-add an empty array even though we potentially just added one. Get over it, or else there'd have to be much more logic to determine when and where to insert the new dictionary to save what like a few milliseconds?
            _saveStateArray[0] = [NSArray array];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    switch (self.mode)
    {
        case GBASaveStateViewControllerModeSaving:
            self.title = NSLocalizedString(@"Save State", @"");
            break;
            
        case GBASaveStateViewControllerModeLoading:
            self.title = NSLocalizedString(@"Load State", @"");
            break;
    }
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSaveStateViewController:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    if (self.mode == GBASaveStateViewControllerModeSaving)
    {
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(tappedAddSaveState:)];
        self.navigationItem.leftBarButtonItem = addButton;
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Save States

- (void)tappedAddSaveState:(UIBarButtonItem *)barButtonItem
{
    [self saveStateAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:-1]];
}

- (void)saveStateAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *generalArray = nil;
    NSDictionary *currentDictionary = nil;
    
    if (indexPath.section == -1)
    {
        generalArray = [self.saveStateArray[1] mutableCopy];
        currentDictionary = nil; // keep it nil
        
        [[NSFileManager defaultManager] createDirectoryAtPath:self.saveStateDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    else
    {
        generalArray = [self.saveStateArray[indexPath.section] mutableCopy];
        currentDictionary = generalArray[indexPath.row];
        
        if ([currentDictionary[@"protected"] boolValue])
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot overwrite protected save state", @"")
                                                            message:NSLocalizedString(@"If you want to delete this save state, swipe it to the left then tap Delete", @"")
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                  otherButtonTitles:nil];
            [alert show];
            
            [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
            
            return;
        }
    }
        
    NSDate *date = [NSDate date];
    NSString *filename = [NSString stringWithFormat:@"%@.sgm", date];
    
    NSString *name = nil;
    BOOL renamed = [currentDictionary[@"renamed"] boolValue];
    
    if (renamed)
    {
        name = currentDictionary[@"name"];
    }
    else
    {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        [dateFormatter setDateStyle:NSDateFormatterLongStyle];
        name = [dateFormatter stringFromDate:date];
    }
    
    NSDictionary *dictionary = @{@"filename": filename, @"name": name, @"protected": @NO, @"renamed": @(renamed)};
    if (indexPath.section == -1)
    {
        [generalArray addObject:dictionary];
    }
    else
    {
        NSDictionary *existingSaveState = generalArray[indexPath.row];
        [[NSFileManager defaultManager] removeItemAtPath:existingSaveState[@"filepath"] error:nil];
        [generalArray replaceObjectAtIndex:indexPath.row withObject:dictionary];
    }
    
    self.saveStateArray[1] = generalArray;
    [self.saveStateArray writeToFile:INFO_PLIST_PATH atomically:YES];
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:willSaveStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self willSaveStateWithFilename:filename];
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] saveStateToFilepath:[self.saveStateDirectory stringByAppendingPathComponent:filename]];
#endif
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:didSaveStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self didSaveStateWithFilename:filename];
    }
    
    if (indexPath.section == -1)
    {
        if ([self.tableView numberOfRowsInSection:1] == 0)
        {
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
        }
        else
        {
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:generalArray.count - 1 inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
    else
    {
        [self dismissSaveStateViewController:nil];
    }
}

- (void)loadStateAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *array = self.saveStateArray[indexPath.section];
    NSDictionary *dictionary = array[indexPath.row];
    
    NSString *filename = dictionary[@"filename"];
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:willLoadStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self willLoadStateWithFilename:filename];
    }
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] loadStateFromFilepath:[self.saveStateDirectory stringByAppendingPathComponent:filename]];
#endif
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:didLoadStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self didLoadStateWithFilename:filename];
    }
    
    [self dismissSaveStateViewController:nil];
}

#pragma mark - Renaming / Protecting

- (void)didDetectLongPressGesture:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan)
    {
        return;
    }
    
    UITableViewCell *cell = (UITableViewCell *)[gestureRecognizer view];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    if (indexPath.section == 0)
    {
        return; // Can't rename auto save
    }
    
    NSMutableArray *array = [self.saveStateArray[indexPath.section] mutableCopy];
    NSDictionary *dictionary = [array[indexPath.row] mutableCopy];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:nil
                                                    cancelButtonTitle:nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedString(@"Rename Save State", @""), nil];
    
    BOOL saveStateProtected = [dictionary[@"protected"] boolValue];
    
    if (saveStateProtected)
    {
        [actionSheet addButtonWithTitle:NSLocalizedString(@"Unprotect Save State", @"")];
    }
    else
    {
        [actionSheet addButtonWithTitle:NSLocalizedString(@"Protect Save State", @"")];
    }
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
    [actionSheet setCancelButtonIndex:actionSheet.numberOfButtons - 1];
    
    [actionSheet showFromRect:[self.tableView rectForRowAtIndexPath:indexPath] inView:self.tableView animated:YES selectionHandler:^(UIActionSheet *sheet, NSInteger buttonIndex) {
        
        if (buttonIndex == 0)
        {
            [self showRenameAlertForSaveStateAtIndexPath:indexPath];
        }
        else if (buttonIndex == 1)
        {
            //
            [self setSaveStateProtected:!saveStateProtected atIndexPath:indexPath];
        }
        
    }];
    
}

- (void)showRenameAlertForSaveStateAtIndexPath:(NSIndexPath *)indexPath
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Rename Save State", @"") message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Rename", @""), nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    
    NSMutableArray *array = [self.saveStateArray[indexPath.section] mutableCopy];
    NSDictionary *dictionary = [array[indexPath.row] mutableCopy];
    
    UITextField *textField = [alert textFieldAtIndex:0];
    textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    
    if ([dictionary[@"renamed"] boolValue])
    {
        textField.text = dictionary[@"name"];
    }
    
    [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 1)
        {
            UITextField *textField = [alertView textFieldAtIndex:0];
            [self renameSaveStateAtIndexPath:indexPath toName:textField.text];
        }
    }];
}

- (void)renameSaveStateAtIndexPath:(NSIndexPath *)indexPath toName:(NSString *)name
{
    NSMutableArray *array = [self.saveStateArray[indexPath.section] mutableCopy];
    NSMutableDictionary *dictionary = [array[indexPath.row] mutableCopy];
    
    dictionary[@"name"] = name;
    dictionary[@"renamed"] = @YES;
    array[indexPath.row] = dictionary;
    self.saveStateArray[indexPath.section] = array;
    
    [self.saveStateArray writeToFile:INFO_PLIST_PATH atomically:YES];
    
    [self.tableView reloadData];
}

- (void)setSaveStateProtected:(BOOL)saveStateProtected atIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *previousArray = [self.saveStateArray[indexPath.section] mutableCopy];
    NSMutableDictionary *dictionary = [previousArray[indexPath.row] mutableCopy];
    
    BOOL alreadyProtected = [dictionary[@"protected"] boolValue];
    
    if (alreadyProtected == saveStateProtected)
    {
        return; // No change
    }
    
    NSInteger newSection = 0;
    
    if (saveStateProtected)
    {
        newSection = 2;
    }
    else
    {
        newSection = 1;
    }
    
    NSMutableArray *destinationArray = [self.saveStateArray[newSection] mutableCopy];
    
    dictionary[@"protected"] = @(saveStateProtected);
    
    [previousArray removeObjectAtIndex:indexPath.row];
    [destinationArray addObject:dictionary];
    
    self.saveStateArray[indexPath.section] = previousArray;
    self.saveStateArray[newSection] = destinationArray;
    
    [self.saveStateArray writeToFile:INFO_PLIST_PATH atomically:YES];
    
    [self.tableView reloadData];
}

#pragma mark - UIAlertView delegate

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    UITextField *textField = [alertView textFieldAtIndex:0];
    return [textField.text length] > 0;
}

#pragma mark - Dismissal

- (void)dismissSaveStateViewController:(UIBarButtonItem *)barButtonItem
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *array = self.saveStateArray[section];
    
    if (section == 0)
    {
        if (self.mode == GBASaveStateViewControllerModeSaving || ![[NSUserDefaults standardUserDefaults] boolForKey:@"autosave"])
        {
            return 0;
        }
    }
        
    return [array count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.saveStateArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSInteger numberOfRows = [self tableView:tableView numberOfRowsInSection:section];
    if (numberOfRows > 0)
    {
        if (section == 0)
        {
            return NSLocalizedString(@"Auto Save", @"");
        }
        else if (section == 1)
        {
            return NSLocalizedString(@"General", @"");
        }
        else if (section == 2)
        {
            return NSLocalizedString(@"Protected", @"");
        }
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        
        UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didDetectLongPressGesture:)];
        [cell addGestureRecognizer:gestureRecognizer];
    }
    
    NSArray *array = self.saveStateArray[indexPath.section];
    NSDictionary *dictionary = array[indexPath.row];
    cell.textLabel.text = dictionary[@"name"];
    
    return cell;
}


 // Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    if (indexPath.section == 0)
    {
        return NO;
    }
    
    return YES;
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
     
        NSString *title = NSLocalizedString(@"Are you sure you want to permanently delete this save state?", @"");
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"dropboxSync"])
        {
            title = [NSString stringWithFormat:@"%@ %@", title, NSLocalizedString(@"It'll be removed from all of your Dropbox connected devices.", @"")];
        }
        
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                                 delegate:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle:NSLocalizedString(@"Delete Save State", @"")
                                                        otherButtonTitles:nil];
        
        [actionSheet showInView:self.view selectionHandler:^(UIActionSheet *sheet, NSInteger buttonIndex) {
            
            if (buttonIndex == 0)
            {
                NSMutableArray *array = [self.saveStateArray[indexPath.section] mutableCopy];
                NSDictionary *dictionary = array[indexPath.row];
                
                [[NSFileManager defaultManager] removeItemAtPath:[self.saveStateDirectory stringByAppendingPathComponent:dictionary[@"filename"]] error:nil];
                [array removeObjectAtIndex:indexPath.row];
                
                self.saveStateArray[indexPath.section] = array;
                [self.saveStateArray writeToFile:INFO_PLIST_PATH atomically:YES];
                
                // Delete the row from the data source
                [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
                
                
            }
            
            [self.tableView setEditing:NO animated:YES];
            
        }];
    }
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (self.mode) {
        case GBASaveStateViewControllerModeLoading:
            [self loadStateAtIndexPath:indexPath];
            break;
            
        case GBASaveStateViewControllerModeSaving:
            [self saveStateAtIndexPath:indexPath];
            break;
    }
}



@end
