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
    GBAControllerButtonUp          =  33,
    GBAControllerButtonDown        =  39,
    GBAControllerButtonLeft        =  35,
    GBAControllerButtonRight       =  37,
    GBAControllerButtonA           =  8,
    GBAControllerButtonB           =  9,
    GBAControllerButtonL           =  10,
    GBAControllerButtonR           =  11,
    GBAControllerButtonStart       =  1,
    GBAControllerButtonSelect      =  0,
    GBAControllerButtonMenu        =  50,
};

@class GBAController;

@protocol GBAControllerDelegate <NSObject>

- (void)controller:(GBAController *)controller didPressButtons:(NSSet *)buttons;
- (void)controller:(GBAController *)controller didReleaseButtons:(NSSet *)buttons;
- (void)controllerDidPressMenuButton:(GBAController *)controller;

@end

@interface GBAController : UIView

@property (weak, nonatomic) id<GBAControllerDelegate> delegate;
@property (copy, nonatomic) NSString *skinFilepath;
@property (assign, nonatomic) GBAControllerOrientation orientation;

// For button placement debugging
- (void)showButtonRects;
- (void)hideButtonRects;

@end
