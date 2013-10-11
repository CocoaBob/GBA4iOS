//
//  GBAROMTableViewControllerAnimator.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/8/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GBAROMTableViewControllerAnimator : NSObject <UIViewControllerAnimatedTransitioning>

@property (assign, nonatomic, getter = isPresenting) BOOL presenting;

@end
