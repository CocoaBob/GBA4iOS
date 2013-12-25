//
//  GBAControllerInput.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/22/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GBAControllerButton)
{
    GBAControllerButtonUp                =  33,
    GBAControllerButtonDown              =  39,
    GBAControllerButtonLeft              =  35,
    GBAControllerButtonRight             =  37,
    GBAControllerButtonA                 =  8,
    GBAControllerButtonB                 =  9,
    GBAControllerButtonL                 =  10,
    GBAControllerButtonR                 =  11,
    GBAControllerButtonStart             =  1,
    GBAControllerButtonSelect            =  0,
    GBAControllerButtonMenu              =  50,
    GBAControllerButtonFastForward       =  51,
    GBAControllerButtonSustainButton     =  52,
};

@protocol GBAControllerInputDelegate <NSObject>

- (void)controllerInput:(id)controllerInput didPressButtons:(NSSet *)buttons;
- (void)controllerInput:(id)controllerInput didReleaseButtons:(NSSet *)buttons;
- (void)controllerInputDidPressMenuButton:(id)controllerInput;

@end

@protocol GBAControllerInput <NSObject>

@property (weak, nonatomic) id<GBAControllerInputDelegate> delegate;

@end
