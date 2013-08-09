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
@property (assign, nonatomic) CGFloat blurAlpha;

- (instancetype)initWithROMFilepath:(NSString *)romFilepath;

- (void)blurWithInitialAlpha:(CGFloat)alpha;
- (void)removeBlur;

@end
