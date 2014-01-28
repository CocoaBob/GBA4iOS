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

- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController startEventROM:(GBAROM *)eventROM;

@optional
- (void)eventDistributionDetailViewController:(GBAEventDistributionDetailViewController *)eventDistributionDetailViewController didDeleteEventDictionary:(NSDictionary *)dictionary;

@end

@interface GBAEventDistributionDetailViewController : UITableViewController

@property (strong, nonatomic) NSURL *imageURL;
@property (strong, nonatomic) NSCache *imageCache;
@property (strong, nonatomic) GBAROM *rom;

@property (weak, nonatomic) id <GBAEventDistributionDetailViewControllerDelegate> delegate;


- (instancetype)initWithEventDictionary:(NSDictionary *)dictionary;

@end
