//
//  GBAPresentMenuViewControllerAnimator.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GBAEmulationViewController.h"

typedef void(^GBAPresentMenuCompletionBlock)(void);

@interface GBAPresentMenuViewControllerAnimator : NSObject <UIViewControllerAnimatedTransitioning>

@property (copy, nonatomic) GBAPresentMenuCompletionBlock completionBlock;
@property (strong, nonatomic) GBAEmulationViewController *emulationViewController;

@end
