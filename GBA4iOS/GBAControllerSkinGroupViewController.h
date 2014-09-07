//
//  GBAControllerSkinGroupViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAControllerSkin.h"

@class GBAControllerSkinGroup;
@class GBAControllerSkinDownloadController;

@interface GBAControllerSkinGroupViewController : UITableViewController

@property (strong, nonatomic, readonly) GBAControllerSkinGroup *controllerSkinGroup;

@property (strong, nonatomic) GBAControllerSkinDownloadController *downloadController;

- (instancetype)initWithControllerSkinGroup:(GBAControllerSkinGroup *)controllerSkinGroup;

@end
