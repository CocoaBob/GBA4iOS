//
//  GBADirectionalControl.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GBADirectionalControlDirection) {
    GBADirectionalControlDirectionUp     = 1 << 0,
    GBADirectionalControlDirectionDown   = 1 << 1,
    GBADirectionalControlDirectionLeft   = 1 << 2,
    GBADirectionalControlDirectionRight  = 1 << 3,
};

@interface GBADirectionalControl : UIControl

@property (readonly, nonatomic) GBADirectionalControlDirection direction;

@end
