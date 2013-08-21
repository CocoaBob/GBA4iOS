//
//  GBANewCheatViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBACheat.h"

@class GBANewCheatViewController;

@protocol GBANewCheatViewControllerDelegate <NSObject>

@optional
- (void)newCheatViewController:(GBANewCheatViewController *)newCheatViewController didSaveCheat:(GBACheat *)cheat;
- (void)newCheatViewControllerDidCancel:(GBANewCheatViewController *)newCheatViewController;

@end

@interface GBANewCheatViewController : UITableViewController

@property (weak, nonatomic) id<GBANewCheatViewControllerDelegate> delegate;

@end
