//
//  GBAEmulationViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/19/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAController.h"

@interface GBAEmulationViewController : UIViewController

@property (readonly, nonatomic) NSString *romFilepath;
@property (copy, nonatomic) NSString *skinFilepath;
@property (strong, nonatomic) UIImageView *blurredSnapshot;
@property (assign, nonatomic) BOOL showBlurredSnapshot;

- (instancetype)initWithROMFilepath:(NSString *)romFilepath;

@end
