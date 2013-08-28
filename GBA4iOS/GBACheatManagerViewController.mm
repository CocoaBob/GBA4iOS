//
//  GBACheatManagerViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACheatManagerViewController.h"
#import "GBACheatEditorViewController.h"
#import "GBACheatManagerTableViewCell.h"

#if !(TARGET_IPHONE_SIMULATOR)
#import "GBAEmulatorCore.h"
#endif

@interface GBACheatManagerViewController () <GBACheatEditorViewControllerDelegate>

@property (strong, nonatomic) NSMutableArray *cheatsArray;

@end

@implementation GBACheatManagerViewController

- (id)initWithROM:(GBAROM *)rom
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)
    {
        _rom = rom;
        [self readCheatsArrayFromDisk];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissCheatManagerViewController:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    self.title = NSLocalizedString(@"Cheat Codes", @"");
    
    [self.tableView registerClass:[GBACheatManagerTableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Helper Methods

- (NSString *)cheatsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *cheatsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Cheats"];
    
    return cheatsDirectory;
}

- (NSString *)cheatsArrayFilepath
{
    NSString *filename = [NSString stringWithFormat:@"%@.plist", self.rom.name];
    return [[self cheatsDirectory] stringByAppendingPathComponent:filename];
}

- (void)readCheatsArrayFromDisk
{
    NSMutableArray *array = [NSMutableArray arrayWithContentsOfFile:[self cheatsArrayFilepath]];
    
    self.cheatsArray = [NSMutableArray arrayWithCapacity:array.count];
    
    @autoreleasepool
    {
        for (NSData *data in array)
        {
            GBACheat *cheat = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            [self.cheatsArray addObject:cheat];
        }
    }
}

- (void)writeCheatsArrayToDisk
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.cheatsArray.count];
    
    @autoreleasepool
    {
        for (GBACheat *cheat in [self.cheatsArray copy])
        {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cheat];
            [array addObject:data];
        }
    }
    
    [array writeToFile:[self cheatsArrayFilepath] atomically:YES];
}

#pragma mark - Managing Cheat Codes

- (void)tappedAddCheatCode:(UIBarButtonItem *)button
{
    GBACheatEditorViewController *cheatEditorViewController = [[GBACheatEditorViewController alloc] init];
    cheatEditorViewController.delegate = self;
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(cheatEditorViewController) animated:YES completion:NULL];
}

- (BOOL)addCheat:(GBACheat *)cheat
{
#if !(TARGET_IPHONE_SIMULATOR)
    return [[GBAEmulatorCore sharedCore] addCheat:cheat];
#endif
    return YES;
}

- (void)enableCheat:(GBACheat *)cheat
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] enableCheat:cheat];
#endif
}

- (void)disableCheat:(GBACheat *)cheat
{
    
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] disableCheat:cheat];
#endif
}

- (void)updateCheats
{
#if !(TARGET_IPHONE_SIMULATOR)
    [[GBAEmulatorCore sharedCore] updateCheats];
#endif
}

#pragma mark - GBANewCheatViewControllerDelegate

- (void)cheatEditorViewController:(GBACheatEditorViewController *)cheatEditorViewController didSaveCheat:(GBACheat *)cheat
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[self cheatsDirectory] withIntermediateDirectories:YES attributes:nil error:nil];
    
    if (![self addCheat:cheat])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Invalid Cheat", @"")
                                                        message:NSLocalizedString(@"Please make sure you typed the cheat code correctly and try again.", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [self.cheatsArray addObject:cheat];
    
    [self writeCheatsArrayToDisk];
    
    [self.tableView reloadData];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)cheatEditorViewControllerDidCancel:(GBACheatEditorViewController *)cheatEditorViewController
{
    [self dismissViewControllerAnimated:YES completion:NULL];
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
    
    if (cheat.enabled)
    {
        cell.detailTextLabel.text = NSLocalizedString(@"Enabled", @"");
    }
    else
    {
        cell.detailTextLabel.text = @"";
    }
    
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
        [self writeCheatsArrayToDisk];
        
        [self updateCheats];
        
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    [self.cheatsArray exchangeObjectAtIndex:sourceIndexPath.row withObjectAtIndex:destinationIndexPath.row];
    [self writeCheatsArrayToDisk];
    
    [self updateCheats];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBACheat *cheat = [self.cheatsArray objectAtIndex:indexPath.row];
    
    if (cheat.enabled)
    {
        cheat.enabled = NO;
        [self disableCheat:cheat];
    }
    else
    {
        cheat.enabled = YES;
        [self enableCheat:cheat];
    }
    
    [self writeCheatsArrayToDisk];
        
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - Dismissal

- (void)dismissCheatManagerViewController:(UIBarButtonItem *)button
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

@end
