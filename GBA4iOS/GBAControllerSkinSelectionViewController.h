//
//  GBAControllerSkinSelectionViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAControllerSkinDetailViewController.h"

@interface GBAControllerSkinSelectionViewController : UITableViewController

@property (assign, nonatomic) GBAControllerSkinOrientation controllerOrientation;
@property (assign, nonatomic) GBAControllerSkinType controllerSkinType;

@end
