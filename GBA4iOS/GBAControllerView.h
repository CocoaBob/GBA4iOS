//
//  GBAControllerView.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAController.h"

@class GBAControllerView;

@protocol GBAControllerViewDelegate <NSObject>

- (void)controllerView:(GBAControllerView *)controller didPressButtons:(NSSet *)buttons;
- (void)controllerView:(GBAControllerView *)controller didReleaseButtons:(NSSet *)buttons;
- (void)controllerViewDidPressMenuButton:(GBAControllerView *)controller;

@end

@interface GBAControllerView : UIView

@property (weak, nonatomic) id<GBAControllerViewDelegate> delegate;
@property (strong, nonatomic) GBAController *controller;
@property (assign, nonatomic) GBAControllerOrientation orientation;

// For button placement debugging
- (void)showButtonRects;
- (void)hideButtonRects;


@end
