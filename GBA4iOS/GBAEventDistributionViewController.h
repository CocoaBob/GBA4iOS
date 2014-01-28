//
//  GBAEventDistributionViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/4/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAEmulationViewController.h"

@class GBAROM;
@class GBAEventDistributionViewController;

@protocol GBAEventDistributionViewControllerDelegate <NSObject>

@optional
- (void)eventDistributionViewController:(GBAEventDistributionViewController *)eventDistributionViewController willStartEvent:(GBAROM *)eventROM;
- (void)eventDistributionViewController:(GBAEventDistributionViewController *)eventDistributionViewController didFinishEvent:(GBAROM *)eventROM;
- (void)eventDistributionViewControllerWillDismiss:(GBAEventDistributionViewController *)eventDistributionViewController;

@end

@interface GBAEventDistributionViewController : UITableViewController

@property (readonly, strong, nonatomic) GBAROM *rom;
@property (strong, nonatomic) GBAEmulationViewController *emulationViewController;
@property (weak, nonatomic) id<GBAEventDistributionViewControllerDelegate> delegate;

- (instancetype)initWithROM:(GBAROM *)rom;

- (void)finishCurrentEvent;

@end
