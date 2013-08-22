//
//  GBACheatManagerViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACheatManagerViewController.h"
#import "GBANewCheatViewController.h"

#define INFO_PLIST_PATH [self.cheatsDirectory stringByAppendingPathComponent:@"info.plist"]

@interface GBACheatManagerViewController () <GBANewCheatViewControllerDelegate>

@property (strong, nonatomic) NSMutableArray *cheatsArray;

@end

@implementation GBACheatManagerViewController

- (id)initWithCheatsDirectory:(NSString *)directory
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)
    {
        _cheatsDirectory = [directory copy];
        
        _cheatsArray = [NSMutableArray arrayWithContentsOfFile:INFO_PLIST_PATH];
        
        if (_cheatsArray == nil)
        {
            _cheatsArray = [[NSMutableArray alloc] init];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissCheatManagerViewController:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(tappedAddCheatCode:)];
    self.navigationItem.leftBarButtonItem = addButton;
    
    self.title = NSLocalizedString(@"Cheat Codes", @"");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Managing Cheat Codes

- (void)tappedAddCheatCode:(UIBarButtonItem *)button
{
    GBANewCheatViewController *newCheatViewController = [[GBANewCheatViewController alloc] init];
    newCheatViewController.delegate = self;
    [self presentViewController:RST_CONTAIN_IN_NAVIGATION_CONTROLLER(newCheatViewController) animated:YES completion:NULL];
}

#pragma mark - GBANewCheatViewControllerDelegate

- (void)newCheatViewController:(GBANewCheatViewController *)newCheatViewController didSaveCheat:(GBACheat *)cheat
{
    [[NSFileManager defaultManager] createDirectoryAtPath:self.cheatsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *filename = [NSString stringWithFormat:@"%@.gbacheat", cheat.name];
    NSString *filepath = [self.cheatsDirectory stringByAppendingPathComponent:filename];
    [self.cheatsArray addObject:@{@"filepath": filepath, @"enabled": @YES}];
    [self.cheatsArray writeToFile:INFO_PLIST_PATH atomically:YES];
    
    if ([self.delegate respondsToSelector:@selector(cheatManagerViewController:didAddCheat:)])
    {
        [self.delegate cheatManagerViewController:self didAddCheat:cheat];
    }
    
    [NSKeyedArchiver archiveRootObject:cheat toFile:filepath];
    
    [self.tableView reloadData];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)newCheatViewControllerDidCancel:(GBANewCheatViewController *)newCheatViewController
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        cell.detailTextLabel.textColor = [UIColor purpleColor];
    }
    
    NSDictionary *dictionary = [self.cheatsArray objectAtIndex:indexPath.row];
    
    NSString *filepath = dictionary[@"filepath"];
    BOOL enabled = [dictionary[@"enabled"] boolValue];
    GBACheat *cheat = [NSKeyedUnarchiver unarchiveObjectWithFile:filepath];
    
    cell.textLabel.text = cheat.name;
    
    if (enabled)
    {
        cell.detailTextLabel.text = NSLocalizedString(@"Enabled", @"");
    }
    else
    {
        cell.detailTextLabel.text = @"";
    }
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableDictionary *dictionary = [[self.cheatsArray objectAtIndex:indexPath.row] mutableCopy];
    
    NSString *filepath = dictionary[@"filepath"];
    BOOL enabled = [dictionary[@"enabled"] boolValue];
    GBACheat *cheat = [NSKeyedUnarchiver unarchiveObjectWithFile:filepath];
    
    if (enabled)
    {
        dictionary[@"enabled"] = @NO;
        
        if ([self.delegate respondsToSelector:@selector(cheatManagerViewController:didDisableCheat:atIndex:)])
        {
            [self.delegate cheatManagerViewController:self didDisableCheat:cheat atIndex:indexPath.row];
        }
    }
    else
    {
        dictionary[@"enabled"] = @YES;
        
        if ([self.delegate respondsToSelector:@selector(cheatManagerViewController:didEnableCheat:atIndex:)])
        {
            [self.delegate cheatManagerViewController:self didEnableCheat:cheat atIndex:indexPath.row];
        }
    }
    
    self.cheatsArray[indexPath.row] = dictionary;
    [self.cheatsArray writeToFile:INFO_PLIST_PATH atomically:YES];
    
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - Dismissal

- (void)dismissCheatManagerViewController:(UIBarButtonItem *)button
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

@end
