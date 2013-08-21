//
//  GBACheatManagerViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBACheat.h"

@class GBACheatManagerViewController;

@protocol GBACheatManagerViewControllerDelegate <NSObject>

@optional
- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController didAddCheat:(GBACheat *)cheat;
- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController didRemoveCheat:(GBACheat *)cheat;
- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController didEnableCheat:(GBACheat *)cheat atIndex:(NSInteger)index;
- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController didDisableCheat:(GBACheat *)cheat atIndex:(NSInteger)index;

@end

@interface GBACheatManagerViewController : UITableViewController

@property (weak, nonatomic) id<GBACheatManagerViewControllerDelegate> delegate;
@property (readonly, copy, nonatomic) NSString *cheatsDirectory;

- (instancetype)initWithCheatsDirectory:(NSString *)directory;

@end
