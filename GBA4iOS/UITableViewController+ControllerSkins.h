//
//  UITableViewController+ControllerSkins.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAControllerSkin.h"

@interface UITableViewController (ControllerSkins)

- (void)updateRowHeightsForDisplayingControllerSkinsWithType:(GBAControllerSkinType)type;

@end
