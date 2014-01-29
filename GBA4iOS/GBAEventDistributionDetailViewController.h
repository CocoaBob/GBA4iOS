//
//  GBAEventDistributionDetailViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/27/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAEventDistributionViewController.h"

@class GBAEventDistributionDetailViewController;

@protocol GBAEventDistributionDetailViewControllerDelegate <NSObject>

- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController startEvent:(GBAEvent *)event forROM:(GBAROM *)rom;

@optional
- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController didDeleteEvent:(GBAEvent *)event;

@end

@interface GBAEventDistributionDetailViewController : UITableViewController

@property (strong, nonatomic) NSURL *imageURL;
@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) GBAROM *rom;
@property (readonly, strong, nonatomic) GBAEvent *event;

@property (weak, nonatomic) id <GBAEventDistributionDetailViewControllerDelegate> delegate;


- (instancetype)initWithEvent:(GBAEvent *)event;

@end
