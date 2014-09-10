//
//  GBAColorSelectionViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/2/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAColorSelectionViewController.h"
#import "GBASettingsViewController.h"

@interface GBAColorSelectionViewController ()

@end

@implementation GBAColorSelectionViewController

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"colorSelectionViewController"];
    if (self)
    {
        // Custom initialization
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Public -

+ (NSString *)localizedNameForGBCColorPalette:(GBCColorPalette)colorPalette
{
    NSString *localizedName = nil;
    
    switch (colorPalette)
    {
        case GBCColorPaletteOriginal:
            localizedName = NSLocalizedString(@"Original", @"");
            break;
            
        case GBCColorPaletteBrown:
            localizedName = NSLocalizedString(@"Brown", @"");
            break;
            
        case GBCColorPaletteRed:
            localizedName = NSLocalizedString(@"Red", @"");
            break;
            
        case GBCColorPaletteDarkBrown:
            localizedName = NSLocalizedString(@"Dark Brown", @"");
            break;
            
        case GBCColorPalettePastelMix:
            localizedName = NSLocalizedString(@"Pastel Mix", @"");
            break;
            
        case GBCColorPaletteOrange:
            localizedName = NSLocalizedString(@"Orange", @"");
            break;
            
        case GBCColorPaletteYellow:
            localizedName = NSLocalizedString(@"Yellow", @"");
            break;
            
        case GBCColorPaletteBlue:
            localizedName = NSLocalizedString(@"Blue", @"");
            break;
            
        case GBCColorPaletteDarkBlue:
            localizedName = NSLocalizedString(@"Dark Blue", @"");
            break;
            
        case GBCColorPaletteGray:
            localizedName = NSLocalizedString(@"Gray", @"");
            break;
            
        case GBCColorPaletteGreen:
            localizedName = NSLocalizedString(@"Green", @"");
            break;
            
        case GBCColorPaletteDarkGreen:
            localizedName = NSLocalizedString(@"Dark Green", @"");
            break;
            
        case GBCColorPaletteReverse:
            localizedName = NSLocalizedString(@"Reverse", @"");
            break;
            
        default:
            localizedName = NSLocalizedString(@"Original", @"");
            break;
    }
    
    return localizedName;
}

#pragma mark - UITableViewDataSource -

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    GBCColorPalette selectedColorPalette = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsSelectedColorPaletteKey];
    
    if (indexPath.row == selectedColorPalette)
    {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GBCColorPalette selectedColorPalette = indexPath.row;
    [[NSUserDefaults standardUserDefaults] setInteger:selectedColorPalette forKey:GBASettingsSelectedColorPaletteKey];
    
    [self.tableView reloadData];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDidChangeNotification object:self userInfo:@{@"key": GBASettingsSelectedColorPaletteKey, @"value": @(selectedColorPalette)}];
    
}

@end
