//
//  GBAColorSelectionViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/2/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GBCColorPalette)
{
    GBCColorPaletteOriginal     = 0,
    GBCColorPaletteBrown        = 1,
    GBCColorPaletteRed          = 2,
    GBCColorPaletteDarkBrown    = 3,
    GBCColorPalettePastelMix    = 4,
    GBCColorPaletteOrange       = 5,
    GBCColorPaletteYellow       = 6,
    GBCColorPaletteBlue         = 7,
    GBCColorPaletteDarkBlue     = 8,
    GBCColorPaletteGray         = 9,
    GBCColorPaletteGreen        = 10,
    GBCColorPaletteDarkGreen    = 11,
    GBCColorPaletteReverse      = 12,
};

@interface GBAColorSelectionViewController : UITableViewController

+ (NSString *)localizedNameForGBCColorPalette:(GBCColorPalette)colorPalette;

@end
