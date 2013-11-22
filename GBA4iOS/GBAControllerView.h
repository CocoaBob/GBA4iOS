//
//  GBAControllerView.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAController.h"
#import "GBAControllerInput.h"

@interface GBAControllerView : UIView <GBAControllerInput>

@property (weak, nonatomic) id<GBAControllerInputDelegate> delegate;
@property (strong, nonatomic) GBAController *controller;
@property (assign, nonatomic) GBAControllerOrientation orientation;
@property (assign, nonatomic) CGFloat skinOpacity;

// For button placement debugging
- (void)showButtonRects;
- (void)hideButtonRects;


@end
