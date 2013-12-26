//
//  GBAExternalController_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAExternalController.h"

typedef NS_ENUM(NSInteger, GBAExternalControllerButtonInput)
{
    GBAExternalControllerButtonInputA                   =  0,
    GBAExternalControllerButtonInputB                   =  1,
    GBAExternalControllerButtonInputX                   =  2,
    GBAExternalControllerButtonInputY                   =  3,
    GBAExternalControllerButtonInputUp                  =  4,
    GBAExternalControllerButtonInputDown                =  5,
    GBAExternalControllerButtonInputLeft                =  6,
    GBAExternalControllerButtonInputRight               =  7,
    GBAExternalControllerButtonInputLeftShoulder        =  8,
    GBAExternalControllerButtonInputLeftTrigger         =  9,
    GBAExternalControllerButtonInputRightShoulder       =  10,
    GBAExternalControllerButtonInputRightTrigger        =  11,
};

@interface GBAExternalController ()

+ (GBAControllerButton)controllerButtonForControllerButtonInput:(GBAExternalControllerButtonInput)buttonInput;
+ (NSString *)keyForButtonInput:(GBAExternalControllerButtonInput)buttonInput;

@end
