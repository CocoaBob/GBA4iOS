//
//  GBAControllerSkinDetailViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GBAControllerSkinType)
{
    GBAControllerSkinTypeGBA,
    GBAControllerSkinTypeGBC
};

@interface GBAControllerSkinDetailViewController : UITableViewController

@property (assign, nonatomic) GBAControllerSkinType controllerSkinType;

@end
