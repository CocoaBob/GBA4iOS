//
//  GBAController.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GBAControllerOrientation)
{
    GBAControllerOrientationPortrait,
    GBAControllerOrientationLandscape
};

typedef NS_ENUM(NSInteger, GBAControllerButton)
{
    GBAControllerButtonUp          =  1 << 0,
    GBAControllerButtonDown        =  1 << 1,
    GBAControllerButtonLeft        =  1 << 2,
    GBAControllerButtonRight       =  1 << 3,
    GBAControllerButtonA           =  1 << 4,
    GBAControllerButtonB           =  1 << 5,
    GBAControllerButtonL           =  1 << 6,
    GBAControllerButtonR           =  1 << 7,
    GBAControllerButtonStart       =  1 << 8,
    GBAControllerButtonSelect      =  1 << 9,
};

@interface GBAController : UIControl

@property (copy, nonatomic) NSString *skinFilepath;
@property (assign, nonatomic) GBAControllerOrientation orientation;

@property (readonly, nonatomic) GBAControllerButton pressedButtons;

// For button placement debugging
- (void)showButtonRects;
- (void)hideButtonRects;

@end
