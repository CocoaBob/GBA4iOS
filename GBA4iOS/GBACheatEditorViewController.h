//
//  GBANewCheatViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBACheat.h"
#import "GBAROM.h"

@class GBACheatEditorViewController;

@protocol GBACheatEditorViewControllerDelegate <NSObject>

@optional
- (void)cheatEditorViewController:(GBACheatEditorViewController *)cheatEditorViewController didSaveCheat:(GBACheat *)cheat;
- (void)cheatEditorViewControllerDidCancel:(GBACheatEditorViewController *)cheatEditorViewController;

@end

@interface GBACheatEditorViewController : UITableViewController

@property (weak, nonatomic) id<GBACheatEditorViewControllerDelegate> delegate;
@property (strong, nonatomic) GBACheat *cheat;
@property (assign, nonatomic) GBAROMType romType;

@end
