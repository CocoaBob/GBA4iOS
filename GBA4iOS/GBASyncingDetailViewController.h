//
//  GBASyncingDetailViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAROM_Private.h"

extern NSString * const GBAShouldRestartCurrentGameNotification;

@class GBASyncingDetailViewController;

@protocol GBASyncingDetailViewControllerDelegate <NSObject>

@optional
- (void)syncingDetailViewControllerWillDismiss:(GBASyncingDetailViewController *)syncingDetailViewController;
- (void)syncingDetailViewControllerDidDismiss:(GBASyncingDetailViewController *)syncingDetailViewController;

@end

@interface GBASyncingDetailViewController : UITableViewController

@property (weak, nonatomic) id<GBASyncingDetailViewControllerDelegate> delegate;
@property (readonly, strong, nonatomic) GBAROM *rom;
@property (assign, nonatomic) BOOL showDoneButton;

- (instancetype)initWithROM:(GBAROM *)rom;

@end
