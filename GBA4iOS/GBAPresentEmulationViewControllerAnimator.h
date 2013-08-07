//
//  GBAPresentEmulationViewControllerAnimator.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^GBAPresentEmulationCompletionBlock)(void);

@interface GBAPresentEmulationViewControllerAnimator : NSObject <UIViewControllerAnimatedTransitioning>

@property (copy, nonatomic) GBAPresentEmulationCompletionBlock completionBlock;

@end
