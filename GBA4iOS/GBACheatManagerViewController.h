//
//  GBACheatManagerViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBACheat.h"
#import "GBAROM.h"
#import "UITableViewController+Theming.h"
#import "GBACheatEditorViewController.h"

@class GBACheatManagerViewController;

@protocol GBACheatManagerViewControllerDelegate <NSObject>

@optional
- (void)cheatManagerViewControllerWillDismiss:(GBACheatManagerViewController *)cheatManagerViewController;
- (void)cheatManagerViewController:(GBACheatManagerViewController *)cheatManagerViewController willDismissCheatEditorViewController:(GBACheatEditorViewController *)cheatEditorViewController;

@end

@interface GBACheatManagerViewController : UITableViewController <GBAThemedTableViewController>

@property (readonly, copy, nonatomic) GBAROM *rom;
@property (weak, nonatomic) id<GBACheatManagerViewControllerDelegate> delegate;

- (instancetype)initWithROM:(GBAROM *)rom;

@end
