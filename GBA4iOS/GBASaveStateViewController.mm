//
//  GBASaveStateViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASaveStateViewController.h"
#import "GBASaveStateTableViewCell.h"
#import "GBASyncManager.h"
#import "GBASettingsViewController.h"

#import "GBAEmulatorCore.h"

#import "UIAlertView+RSTAdditions.h"
#import "UIActionSheet+RSTAdditions.h"

@interface GBASaveStateViewController ()

@property (readonly, nonatomic) NSString *saveStateDirectory;
@property (strong, nonatomic) NSMutableArray *saveStateArray;

@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSDateFormatter *readableDateFormatter;

@end

@implementation GBASaveStateViewController
@synthesize theme = _theme;

- (id)initWithROM:(GBAROM *)rom mode:(GBASaveStateViewControllerMode)mode
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)
    {
        _rom = rom;
        _mode = mode;
        
        [self updateSaveStateArray];
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
    
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"Header"];
    
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

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"showedSaveStateAlert"])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning!", @"")
                                                        message:NSLocalizedString(@"Save states are intended to be used as a convenience, and not as the primary saving method. To ensure that save data is never lost or corrupted, please save in-game as you would if you were playing on an actual Game Boy Advance.", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"I Understand", @"") otherButtonTitles:nil];
        [alert show];
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"showedSaveStateAlert"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)disablesAutomaticKeyboardDismissal
{
    return NO;
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
    
    NSMutableDictionary *updatedDictionary = [currentDictionary mutableCopy];
    
    if (updatedDictionary == nil)
    {
        NSDictionary *mostRecentSaveDictionary = [generalArray lastObject];
        NSDate *mostRecentSortingDate = mostRecentSaveDictionary[@"sortingDate"];
        
        NSDate *sortingDate = [self sanitizedDateFromDate:date previousDate:mostRecentSortingDate];
        
        updatedDictionary = [@{@"name": @"", @"sortingDate": sortingDate, @"protected": @NO} mutableCopy];
    }
    
    NSString *originalFilepath = updatedDictionary[@"filepath"];
    
    // Doesn't matter if date is correct or not, doesn't affect sorting
    // Update for all save states, even if it has been renamed, so every save has a different filename; this leads to no conflicted filenames, so we have no problem parsing the names
    updatedDictionary[@"date"] = date;
    
    NSString *filepath = [self filepathForSaveStateDictionary:updatedDictionary];
    updatedDictionary[@"filepath"] = filepath;
    
    if (indexPath.section == -1)
    {
        [generalArray addObject:updatedDictionary];
    }
    else
    {
        [[NSFileManager defaultManager] removeItemAtPath:currentDictionary[@"filepath"] error:nil];
        [generalArray replaceObjectAtIndex:indexPath.row withObject:updatedDictionary];
    }
    
    self.saveStateArray[1] = generalArray;
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:willSaveStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self willSaveStateWithFilename:[filepath lastPathComponent]];
    }
    
    [[GBAEmulatorCore sharedCore] saveStateToFilepath:filepath];
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:didSaveStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self didSaveStateWithFilename:[filepath lastPathComponent]];
    }
    
    [[GBASyncManager sharedManager] prepareToUploadSaveStateAtPath:filepath forROM:self.rom];
    
    if (indexPath.section > -1 && ![filepath isEqualToString:originalFilepath])
    {
        [[GBASyncManager sharedManager] prepareToDeleteSaveStateAtPath:originalFilepath forROM:self.rom];
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
    
    NSString *filepath = dictionary[@"filepath"];
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:willLoadStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self willLoadStateWithFilename:[filepath lastPathComponent]];
    }
    
    [[GBAEmulatorCore sharedCore] loadStateFromFilepath:filepath];
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewController:didLoadStateWithFilename:)])
    {
        [self.delegate saveStateViewController:self didLoadStateWithFilename:[filepath lastPathComponent]];
    }
    
    [self dismissSaveStateViewController:nil];
}

- (void)updateSaveStateArray
{
    NSMutableArray *saveStateArray = [NSMutableArray array];
    
    NSMutableArray *autosaveArray = [NSMutableArray array];
    NSMutableArray *generalArray = [NSMutableArray array];
    NSMutableArray *protectedArray = [NSMutableArray array];
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.saveStateDirectory error:nil];
        
    for (NSString *filename in contents)
    {
        
        if (![[filename pathExtension] isEqualToString:@"sgm"])
        {
            continue;
        }
        
        NSString *filepath = [self.saveStateDirectory stringByAppendingPathComponent:filename];
        
        if ([[filename lowercaseString] isEqualToString:@"autosave.sgm"])
        {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
            [autosaveArray addObject:@{@"name": [filename stringByDeletingPathExtension],
                                       @"filepath": filepath,
                                       @"date": [attributes fileModificationDate],
                                       @"sortingDate": [attributes fileCreationDate],
                                       @"protected": @YES,
                                       @"renamed": @NO}];
            continue;
        }
        
        // Title may have dashes, so can't use this
        // NSArray *components = [filename componentsSeparatedByString:@"-"];
        
        NSUInteger stringLength = [filename length];
        
        if (stringLength < 35)
        {
            continue;
        }
        
        // Example filename: 41 chars
        // name - modified date - sorting date (typically, but not always, creation date) - general/protected
        // hello-yyyyMMddHHmmss-yyyyMMddHHmmss-P.sgm
        
        NSString *name = @"";
        
        // If filename has exactly 35 characters, it has no name, and the dash between the name and modified date isn't there
        if (stringLength > 35)
        {
            name = [filename stringByReplacingCharactersInRange:NSMakeRange(stringLength - 36, 36) withString:@""];
        }
        
        NSString *dateString = [filename substringWithRange:NSMakeRange(stringLength - 35, 14)];
        NSDate *modifiedDate = [self.dateFormatter dateFromString:dateString];
        
        if (modifiedDate == nil)
        {
            modifiedDate = [NSDate date];
        }
        
        dateString = [filename substringWithRange:NSMakeRange(stringLength - 20, 14)];
        NSDate *sortingDate = [self.dateFormatter dateFromString:dateString];
        
        if (sortingDate == nil)
        {
            sortingDate = [NSDate date];
        }
        
        BOOL renamed = ([name length] > 0);
        
        NSString *saveStateTypeString = [[filename substringWithRange:NSMakeRange(stringLength - 5, 1)] uppercaseString];
        
        NSMutableDictionary *dictionary = [@{@"name": name,
                                             @"filepath": filepath,
                                             @"date": modifiedDate,
                                             @"sortingDate": sortingDate,
                                             @"renamed": @(renamed)} mutableCopy];
        
        if ([saveStateTypeString isEqualToString:@"G"])
        {
            dictionary[@"protected"] = @NO;
            [generalArray addObject:dictionary];
        }
        else if ([saveStateTypeString isEqualToString:@"P"])
        {
            dictionary[@"protected"] = @YES;
            [protectedArray addObject:dictionary];
        }
    }
    
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"sortingDate" ascending:YES];
    [generalArray sortUsingDescriptors:@[descriptor]];
    [protectedArray sortUsingDescriptors:@[descriptor]];
    
    [saveStateArray addObject:autosaveArray];
    [saveStateArray addObject:generalArray];
    [saveStateArray addObject:protectedArray];
    
    self.saveStateArray = saveStateArray;
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
    
    NSString *originalFilepath = dictionary[@"filepath"];
    
    dictionary[@"name"] = name;
    dictionary[@"renamed"] = @YES;
    
    NSString *filepath = [self filepathForSaveStateDictionary:dictionary];
    dictionary[@"filepath"] = filepath;
    
    array[indexPath.row] = dictionary;
    self.saveStateArray[indexPath.section] = array;
    
    [[NSFileManager defaultManager] moveItemAtPath:originalFilepath toPath:filepath error:nil];
    
    [self.tableView reloadData];
    
    [[GBASyncManager sharedManager] prepareToRenameSaveStateAtPath:originalFilepath toNewName:[filepath lastPathComponent] forROM:self.rom];
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
    
    NSString *originalFilepath = dictionary[@"filepath"];
    
    NSMutableArray *destinationArray = [self.saveStateArray[newSection] mutableCopy];
    
    DLog(@"Destination: %@", destinationArray);
    
    // Sorting Date
    NSDictionary *mostRecentSaveDictionary = [destinationArray lastObject];
    NSDate *mostRecentSortingDate = mostRecentSaveDictionary[@"sortingDate"];
    
    NSDate *sortingDate = [self sanitizedDateFromDate:[NSDate date] previousDate:mostRecentSortingDate];
    
    dictionary[@"protected"] = @(saveStateProtected);
    dictionary[@"sortingDate"] = sortingDate;
    
    // Filepath
    NSString *filepath = [self filepathForSaveStateDictionary:dictionary];
    
    dictionary[@"filepath"] = filepath;
    
    [previousArray removeObjectAtIndex:indexPath.row];
    [destinationArray addObject:dictionary];
    
    self.saveStateArray[indexPath.section] = previousArray;
    self.saveStateArray[newSection] = destinationArray;
    
    [[NSFileManager defaultManager] moveItemAtPath:originalFilepath toPath:filepath error:nil];
    
    [self.tableView reloadData];
    
    [[GBASyncManager sharedManager] prepareToRenameSaveStateAtPath:originalFilepath toNewName:[filepath lastPathComponent] forROM:self.rom];
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
    
    if ([self.delegate respondsToSelector:@selector(saveStateViewControllerWillDismiss:)])
    {
        [self.delegate saveStateViewControllerWillDismiss:self];
    }
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
    
    NSString *name = nil;
    
    if ([dictionary[@"renamed"] boolValue])
    {
        name = dictionary[@"name"];
    }
    else
    {
        name = [self.readableDateFormatter stringFromDate:dictionary[@"date"]];
    }
    
    cell.textLabel.text = name;
    
    [self themeTableViewCell:cell];
    
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
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsDropboxSyncKey])
        {
            title = [NSString stringWithFormat:@"%@ %@", title, NSLocalizedString(@"It'll be removed from all of your Dropbox connected devices.", @"")];
        }
        
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                                 delegate:nil
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                   destructiveButtonTitle:NSLocalizedString(@"Delete Save State", @"")
                                                        otherButtonTitles:nil];
        
        UIView *presentationView = self.view;
        CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
        
        [actionSheet showFromRect:rect inView:presentationView animated:YES selectionHandler:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
            if (buttonIndex == 0)
            {
                NSMutableArray *array = [self.saveStateArray[indexPath.section] mutableCopy];
                NSDictionary *dictionary = array[indexPath.row];
                
                NSString *filepath = dictionary[@"filepath"];
                
                [[NSFileManager defaultManager] removeItemAtPath:dictionary[@"filepath"] error:nil];
                [array removeObjectAtIndex:indexPath.row];
                
                self.saveStateArray[indexPath.section] = array;
                
                // Delete the row from the data source
                [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
                
                [[GBASyncManager sharedManager] prepareToDeleteSaveStateAtPath:filepath forROM:self.rom];
                
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

#pragma mark - Helped Methods

- (NSString *)filepathForSaveStateDictionary:(NSDictionary *)dictionary
{
    NSString *name = dictionary[@"name"];
    NSString *modifiedDateString = [self.dateFormatter stringFromDate:dictionary[@"date"]];
    NSString *sortingDateString = [self.dateFormatter stringFromDate:dictionary[@"sortingDate"]];
    
    NSString *saveStateTypeString = nil;
    
    if ([dictionary[@"protected"] boolValue])
    {
        saveStateTypeString = @"P";
    }
    else
    {
        saveStateTypeString = @"G";
    }
    
    if (name == nil)
    {
        name = @"";
    }
    
    NSString *filename = [NSString stringWithFormat:@"%@-%@-%@.sgm", modifiedDateString, sortingDateString, saveStateTypeString];
    
    if ([name length] > 0)
    {
        filename = [NSString stringWithFormat:@"%@-%@", name, filename];
    }
    
    return [self.saveStateDirectory stringByAppendingPathComponent:filename];
}

- (NSDate *)sanitizedDateFromDate:(NSDate *)date previousDate:(NSDate *)previousDate
{
    if (previousDate == nil)
    {
        DLog(@"Previous Date: %@", previousDate);
        return date;
    }
    
    NSDate *sanitizedDate = date;
    
    // If user changes the date back, we need to make sure it is still after the last date.
    // Sure, if the user puts the clock ahead the sortingDate would be forever in the future, but the user never would know this, and it will still work as intended
    if ([previousDate compare:date] != NSOrderedAscending)
    {
        sanitizedDate = [NSDate dateWithTimeInterval:18 sinceDate:previousDate];
    }
    
    return sanitizedDate;
}

- (NSString *)saveStateDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *saveStateParentDirectory = [documentsDirectory stringByAppendingPathComponent:@"Save States"];
    NSString *saveStateDirectory = [saveStateParentDirectory stringByAppendingPathComponent:self.rom.name];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:saveStateDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return saveStateDirectory;
}

#pragma mark - Getters / Setters

- (void)setTheme:(GBAThemedTableViewControllerTheme)theme
{
    _theme = theme;
    
    [self updateTheme];
}

- (NSDateFormatter *)dateFormatter
{
    if (_dateFormatter == nil)
    {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    }
    
    return _dateFormatter;
}

- (NSDateFormatter *)readableDateFormatter
{
    if (_readableDateFormatter == nil)
    {
        _readableDateFormatter = [[NSDateFormatter alloc] init];
        [_readableDateFormatter setTimeStyle:NSDateFormatterShortStyle];
        [_readableDateFormatter setDateStyle:NSDateFormatterLongStyle];
    }
    
    return _readableDateFormatter;
}

@end
