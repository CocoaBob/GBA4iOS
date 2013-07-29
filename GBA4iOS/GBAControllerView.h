//
//  GBAControllerView.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GBAControllerOrientation)
{
    GBAControllerOrientationPortrait,
    GBAControllerOrientationLandscape
};

typedef NS_ENUM(NSInteger, GBAControllerButton)
{
    GBAControllerButtonDPad,
    GBAControllerButtonA,
    GBAControllerButtonB,
    GBAControllerButtonAB,
    GBAControllerButtonL,
    GBAControllerButtonR,
    GBAControllerButtonStart,
    GBAControllerButtonSelect,
    GBAControllerButtonMenu,
    GBAControllerButtonScreen
};

typedef NS_ENUM(NSInteger, GBAControllerDPadDirection) {
    GBAControllerDPadDirectionUp     = 1 << 0,
    GBAControllerDPadDirectionDown   = 1 << 1,
    GBAControllerDPadDirectionLeft   = 1 << 2,
    GBAControllerDPadDirectionRight  = 1 << 3,
};

@interface GBAControllerView : UIControl

@property (copy, nonatomic) NSString *skinFilepath;
@property (assign, nonatomic) GBAControllerOrientation orientation;

@property (readonly, nonatomic) GBAControllerDPadDirection dPadDirection;
@property (readonly, nonatomic) GBAControllerButton selectedButtons;

// For button placement debugging
- (void)showButtonRects;
- (void)hideButtonRects;

@end
