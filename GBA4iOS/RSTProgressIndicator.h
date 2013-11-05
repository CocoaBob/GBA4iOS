//
//  RSTProgressIndicator.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RSTProgressIndicatorStyle)
{
    RSTProgressIndicatorStyleActivityIndicator, // For
    RSTProgressIndicatorStyleProgressView, // For
};

@interface RSTProgressIndicator : UIView

@property (assign, nonatomic) CGFloat progress;
@property (strong, nonatomic) UIColor *tintColor;
@property (assign, nonatomic) RSTProgressIndicatorStyle style;

- (void)showInView:(UIView *)view;

@end
