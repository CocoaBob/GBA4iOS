//
//  GBAControllerSkinDownloadGroupsViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/6/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAControllerSkin.h"

@interface GBAControllerSkinDownloadViewController : UITableViewController

@property (assign, nonatomic, readonly) GBAControllerSkinType controllerSkinType;

- (instancetype)initWithControllerSkinType:(GBAControllerSkinType)controllerSkinType;

@end
