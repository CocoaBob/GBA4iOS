//
//  GBAPresentOverlayViewControllerAnimator.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/10/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GBAPresentOverlayViewControllerAnimator : NSObject <UIViewControllerAnimatedTransitioning>

@property (assign, nonatomic, getter = isPresenting) BOOL presenting;

@end
