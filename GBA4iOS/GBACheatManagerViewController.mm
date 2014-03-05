//
//  GBACheatManagerViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACheatManagerViewController.h"
#import "GBACheatManagerTableViewCell.h"
#import "GBACheat.h"
#import "GBASyncManager.h"

#import "GBAEmulatorCore.h"

#define ENABLED_CHEATS_FILEPATH [[self cheatsDirectory] stringByAppendingPathComponent:@"enabledCheats.plist"]

@interface GBACheatManagerViewController () <GBACheatEditorViewControllerDelegate>

@property (strong, nonatomic) NSMutableArray *cheatsArray;
@property (strong, nonatomic) NSMutableDictionary *enabledCheatsDictionary;

@end

@implementation GBACheatManagerViewController
@synthesize theme = _theme;

- (id)initWithROM:(GBAROM *)rom
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)
    {
        _rom = rom;
        [self updateCheatsArray];
        
        _enabledCheatsDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:ENABLED_CHEATS_FILEPATH];
        
        if (_enabledCheatsDictionary == nil)
        {
            _enabledCheatsDictionary = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissCheatManagerViewController:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    self.title = NSLocalizedString(@"Cheat Codes", @"");
    
    [self.tableView registerClass:[GBACheatManagerTableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"showedCheatsAlert"])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning!", @"")
                                                        message:NSLocalizedString(@"Cheats should only be used if you know exactly what you are doing. Incorrect usage of cheats, such as entering codes incorrectly or using potentially dangerous codes, can have serious side effects in the game. These can result in anything from major graphical glitches to the loss of save data.", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"I Understand", @"") otherButtonTitles:nil];
        [alert show];
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"showedCheatsAlert"];
        [[NSUserDefaults standardUserDefaults] synchronize];
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

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - Helper Methods

- (NSString *)cheatsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *cheatsParentDirectory = [documentsDirectory stringByAppendingPathComponent:@"Cheats"];
    NSString *cheatsDirectory = [cheatsParentDirectory stringByAppendingPathComponent:self.rom.name];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:cheatsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return cheatsDirectory;
}

- (void)updateCheatsArray
{
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self cheatsDirectory] error:nil];
    
    NSMutableArray *cheatsArray = [NSMutableArray arrayWithCapacity:[contents count]];
    
    for (NSString *filename in contents)
    {
        if (![[[filename pathExtension] lastPathComponent] isEqualToString:@"gbacheat"])
        {
            continue;
        }
        
        NSString *filepath = [[self cheatsDirectory] stringByAppendingPathComponent:filename];
        
        GBACheat *cheat = [GBACheat cheatWithContentsOfFile:filepath];
        
        if ([filename length] != 45) // 36 character UUID String + '.gbacheat' extension
        {
            [cheat generateNewUID];
            
            NSString *newFilepath = [[self cheatsDirectory] stringByAppendingPathComponent:[cheat.uid stringByAppendingPathExtension:@"gbacheat"]];
            
            // Copy it so the filepath doesn't change
            GBACheat *oldCheat = [cheat copy];
            
            [cheat writeToFile:newFilepath];
            
            [[GBASyncManager sharedManager] prepareToUploadCheat:cheat forROM:self.rom];
            [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
            [[GBASyncManager sharedManager] prepareToDeleteCheat:oldCheat forROM:self.rom];
        }
        
        [cheatsArray addObject:cheat];
    }
    
    [cheatsArray sortUsingComparator:^(GBACheat *a, GBACheat *b) {
        
        NSComparisonResult result = [@(a.index) compare:@(b.index)];
        
        if (result != NSOrderedSame)
        {
            return result;
        }
        
        NSDictionary *aAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[a filepath] error:nil];
        NSDictionary *bAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[b filepath] error:nil];
        
        return [aAttributes[NSFileModificationDate] compare:bAttributes[NSFileModificationDate]];
    }];
    
    self.cheatsArray = cheatsArray;
}

#pragma mark - Managing Cheat Codes

- (void)tappedAddCheatCode:(UIBarButtonItem *)button
{
    GBACheatEditorViewController *cheatEditorViewController = [[GBACheatEditorViewController alloc] init];
    cheatEditorViewController.romType = self.rom.type;
    cheatEditorViewController.delegate = self;
    
    UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(cheatEditorViewController);
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [[UIApplication sharedApplication] setStatusBarStyle:[cheatEditorViewController preferredStatusBarStyle] animated:YES];
    
    [self presentViewController:navigationController animated:YES completion:NULL];
    
}

- (BOOL)addCheat:(GBACheat *)cheat
{
    BOOL cheatAlreadyExists = [self.cheatsArray containsObject:cheat];
    
    BOOL success = [[GBAEmulatorCore sharedCore] addCheat:cheat];
    
    if (success && !cheatAlreadyExists)
    {
        self.enabledCheatsDictionary[cheat.uid] = @YES;
        [self.enabledCheatsDictionary writeToFile:ENABLED_CHEATS_FILEPATH atomically:YES];
    }
    
    return success;
}

- (void)enableCheat:(GBACheat *)cheat
{
    [[GBAEmulatorCore sharedCore] enableCheat:cheat];
}

- (void)disableCheat:(GBACheat *)cheat
{
    [[GBAEmulatorCore sharedCore] disableCheat:cheat];
}

- (BOOL)updateCheats
{
    return [[GBAEmulatorCore sharedCore] updateCheats];
}

#pragma mark - GBANewCheatViewControllerDelegate

- (void)cheatEditorViewController:(GBACheatEditorViewController *)cheatEditorViewController didSaveCheat:(GBACheat *)cheat
{
    if (![self addCheat:cheat])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Invalid Cheat", @"")
                                                        message:NSLocalizedString(@"Please make sure you typed the cheat code in the correct format and try again.", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert show];
                
        return;
    }
    
    if ([self.cheatsArray containsObject:cheat])
    {
        NSUInteger index = [self.cheatsArray indexOfObject:cheat];
        [self.cheatsArray replaceObjectAtIndex:index withObject:cheat];
    }
    else
    {
        cheat.index = [self.cheatsArray count];
        [self.cheatsArray addObject:cheat];
    }
    
    NSString *filepath = cheat.filepath;
    
    if (filepath == nil)
    {
        filepath = [[self cheatsDirectory] stringByAppendingPathComponent:[cheat.uid stringByAppendingPathExtension:@"gbacheat"]];
    }
    
    [cheat writeToFile:filepath];
    
    [[GBASyncManager sharedManager] prepareToUploadCheat:cheat forROM:self.rom];
    
    [self updateCheats]; // GBC cheats need to be updated, and also is needed for both to keep the cheats in order
    
    [self.tableView reloadData];
    
    if ([self.delegate respondsToSelector:@selector(cheatManagerViewController:willDismissCheatEditorViewController:)])
    {
        [self.delegate cheatManagerViewController:self willDismissCheatEditorViewController:cheatEditorViewController];
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
    
    [[UIApplication sharedApplication] setStatusBarStyle:[self preferredStatusBarStyle] animated:YES];
}

- (void)cheatEditorViewControllerDidCancel:(GBACheatEditorViewController *)cheatEditorViewController
{
    if ([self.delegate respondsToSelector:@selector(cheatManagerViewController:willDismissCheatEditorViewController:)])
    {
        [self.delegate cheatManagerViewController:self willDismissCheatEditorViewController:cheatEditorViewController];
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
    
    [[UIApplication sharedApplication] setStatusBarStyle:[self preferredStatusBarStyle] animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.cheatsArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    GBACheatManagerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    GBACheat *cheat = [self.cheatsArray objectAtIndex:indexPath.row];
    
    cell.textLabel.text = cheat.name;
    
    if ([[self.enabledCheatsDictionary objectForKey:cheat.uid] boolValue])
    {
        cell.detailTextLabel.text = NSLocalizedString(@"Enabled", @"");
    }
    else
    {
        cell.detailTextLabel.text = @"";
    }
    
    [self themeTableViewCell:cell];
    
    return cell;
}

#pragma mark Editing


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (editing)
    {
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(tappedAddCheatCode:)];
        [self.navigationItem setRightBarButtonItem:addButton animated:animated];
    }
    else
    {
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissCheatManagerViewController:)];
        [self.navigationItem setRightBarButtonItem:doneButton animated:animated];
    }
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        GBACheat *cheat = self.cheatsArray[indexPath.row];
        
        [self.cheatsArray removeObjectAtIndex:indexPath.row];
        [self.enabledCheatsDictionary removeObjectForKey:cheat.uid];
        
        [[NSFileManager defaultManager] removeItemAtPath:cheat.filepath error:nil];
        
        [self updateCheats];
        
        [[GBASyncManager sharedManager] prepareToDeleteCheat:cheat forROM:self.rom];
        
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    GBACheat *movingCheat = self.cheatsArray[sourceIndexPath.row];
    [self.cheatsArray removeObjectAtIndex:sourceIndexPath.row];
    [self.cheatsArray insertObject:movingCheat atIndex:destinationIndexPath.row];
    
    NSArray *cheatsArray = [self.cheatsArray copy];
    
    [cheatsArray enumerateObjectsUsingBlock:^(GBACheat *cheat, NSUInteger index, BOOL *stop) {
        if (cheat.index == index)
        {
            return;
        }
        
        cheat.index = index;
        
        [cheat writeToFile:cheat.filepath];
        
        [[GBASyncManager sharedManager] prepareToUploadCheat:cheat forROM:self.rom];
    }];
    
    [self updateCheats];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBACheat *cheat = [self.cheatsArray objectAtIndex:indexPath.row];
    
    if ([self.tableView isEditing])
    {
        GBACheatEditorViewController *cheatEditorViewController = [[GBACheatEditorViewController alloc] init];
        cheatEditorViewController.romType = self.rom.type;
        cheatEditorViewController.cheat = cheat;
        cheatEditorViewController.delegate = self;
        
        UINavigationController *navigationController = RST_CONTAIN_IN_NAVIGATION_CONTROLLER(cheatEditorViewController);
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        
        [[UIApplication sharedApplication] setStatusBarStyle:[cheatEditorViewController preferredStatusBarStyle] animated:YES];
        [self presentViewController:navigationController animated:YES completion:NULL];
    }
    else
    {
        
        if ([self.enabledCheatsDictionary[cheat.uid] boolValue])
        {
            self.enabledCheatsDictionary[cheat.uid] = @NO;
            
            [self.enabledCheatsDictionary writeToFile:ENABLED_CHEATS_FILEPATH atomically:YES]; // Write to disk before disabling (needed for GBC cheats)
            
            [self disableCheat:cheat];
        }
        else
        {
            self.enabledCheatsDictionary[cheat.uid] = @YES;
            
            [self.enabledCheatsDictionary writeToFile:ENABLED_CHEATS_FILEPATH atomically:YES]; // Write to disk before enabling (needed for GBC cheats)
            
            [self enableCheat:cheat];
        }
        
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - Dismissal

- (void)dismissCheatManagerViewController:(UIBarButtonItem *)button
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
    
    if ([self.delegate respondsToSelector:@selector(cheatManagerViewControllerWillDismiss:)])
    {
        [self.delegate cheatManagerViewControllerWillDismiss:self];
    }
}

#pragma mark - Getters/Setters

- (void)setTheme:(GBAThemedTableViewControllerTheme)theme
{
    _theme = theme;
    
    [self updateTheme];
}

@end
