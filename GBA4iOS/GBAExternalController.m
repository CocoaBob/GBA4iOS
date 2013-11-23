//
//  GBAExternalController.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/22/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAExternalController.h"
#import "GBAControllerSkin.h"

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

@property (strong, nonatomic) NSMutableDictionary *previousButtonValues; // Don't use controller snapshots cause we only want to update individual buttons each time

@end

@implementation GBAExternalController

- (instancetype)initWithController:(GCController *)controller
{
    self = [super init];
    if (self)
    {
        _controller = controller;
        
        _previousButtonValues = [NSMutableDictionary dictionary];
        
        [self configureController];
    }
    
    return self;
}

+ (GBAExternalController *)externalControllerWithController:(GCController *)controller
{
    GBAExternalController *externalController = [[GBAExternalController alloc] initWithController:controller];
    return externalController;
}

- (void)configureController
{
    __weak __typeof__(self) weakSelf = self;
    self.controller.controllerPausedHandler = ^(GCController *controller)
    {
        [weakSelf.delegate controllerInputDidPressMenuButton:weakSelf];
    };
    
    GCGamepad *gamepad = self.controller.gamepad;
    
    // Standard Buttons
    gamepad.buttonA.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputA wasPressedWithValue:value];
    };
    
    gamepad.buttonB.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputB wasPressedWithValue:value];
    };
    
    gamepad.buttonX.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputX wasPressedWithValue:value];
    };
    
    gamepad.buttonY.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputY wasPressedWithValue:value];
    };
    
    gamepad.leftShoulder.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputLeftShoulder wasPressedWithValue:value];
    };
    
    gamepad.rightShoulder.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputRightShoulder wasPressedWithValue:value];
    };
    
    // D-Pad
    gamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue)
    {
        [self controllerDPadDidChange:dpad];
    };
    
    
    // Extended Profile
    
    GCExtendedGamepad *extendedGamepad = self.controller.extendedGamepad;
    
    if (extendedGamepad == nil)
    {
        return;
    }
    
    extendedGamepad.leftTrigger.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputLeftTrigger wasPressedWithValue:value];
    };
    
    extendedGamepad.rightTrigger.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputRightTrigger wasPressedWithValue:value];
    };
}

#pragma mark - Controls

- (void)controllerButtonInput:(GBAExternalControllerButtonInput)buttonInput wasPressedWithValue:(float)value
{
    float previousValue = [self.previousButtonValues[@(buttonInput)] floatValue];
    
    GBAControllerButton controllerButton = [self controllerButtonForControllerButtonInput:buttonInput];
    NSSet *set = [NSSet setWithObject:@(controllerButton)];
    
    if (value > 0 && previousValue == 0)
    {
        [self.delegate controllerInput:self didPressButtons:set];
    }
    else if (value == 0 && previousValue > 0)
    {
        [self.delegate controllerInput:self didReleaseButtons:set];
    }
    
    self.previousButtonValues[@(buttonInput)] = @(value);
}

- (void)controllerDPadDidChange:(GCControllerDirectionPad *)dPad
{
    NSMutableSet *pressedButtons = [NSMutableSet set];
    NSMutableSet *releasedButtons = [NSMutableSet set];
    
    // Up
    float previousUpValue = [self.previousButtonValues[@(GBAExternalControllerButtonInputUp)] floatValue];
    if (dPad.up.value > 0 && previousUpValue == 0)
    {
        [pressedButtons addObject:@(GBAControllerButtonUp)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputUp)] = @(dPad.up.value);
    }
    else if (dPad.up.value == 0 && previousUpValue > 0)
    {
        [releasedButtons addObject:@(GBAControllerButtonUp)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputUp)] = @(dPad.up.value);
    }
    
    // Down
    float previousDownValue = [self.previousButtonValues[@(GBAExternalControllerButtonInputDown)] floatValue];
    if (dPad.down.value > 0 && previousDownValue == 0)
    {
        [pressedButtons addObject:@(GBAControllerButtonDown)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputDown)] = @(dPad.down.value);
    }
    else if (dPad.down.value == 0 && previousDownValue > 0)
    {
        [releasedButtons addObject:@(GBAControllerButtonDown)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputDown)] = @(dPad.down.value);
    }
    
    // Left
    float previousLeftValue = [self.previousButtonValues[@(GBAExternalControllerButtonInputLeft)] floatValue];
    if (dPad.left.value > 0 && previousLeftValue == 0)
    {
        [pressedButtons addObject:@(GBAControllerButtonLeft)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputLeft)] = @(dPad.left.value);
    }
    else if (dPad.left.value == 0 && previousLeftValue > 0)
    {
        [releasedButtons addObject:@(GBAControllerButtonLeft)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputLeft)] = @(dPad.left.value);
    }
    
    // Right
    float previousRightValue = [self.previousButtonValues[@(GBAExternalControllerButtonInputRight)] floatValue];
    if (dPad.right.value > 0 && previousRightValue == 0)
    {
        [pressedButtons addObject:@(GBAControllerButtonRight)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputRight)] = @(dPad.right.value);
    }
    else if (dPad.right.value == 0 && previousRightValue > 0)
    {
        [releasedButtons addObject:@(GBAControllerButtonRight)];
        self.previousButtonValues[@(GBAExternalControllerButtonInputRight)] = @(dPad.right.value);
    }
    
    if ([pressedButtons count] > 0)
    {
        [self.delegate controllerInput:self didPressButtons:pressedButtons];
    }
    
    if ([releasedButtons count] > 0)
    {
        [self.delegate controllerInput:self didReleaseButtons:releasedButtons];
    }
}

#pragma mark - Helper Methods

- (GBAControllerButton)controllerButtonForControllerButtonInput:(GBAExternalControllerButtonInput)buttonInput
{
    GBAControllerButton controllerButton = 0;
    
    switch (buttonInput) {
        case GBAExternalControllerButtonInputA:
            controllerButton = GBAControllerButtonA;
            break;
            
        case GBAExternalControllerButtonInputB:
            controllerButton = GBAControllerButtonSelect;
            break;
            
        case GBAExternalControllerButtonInputX:
            controllerButton = GBAControllerButtonB;
            break;
            
        case GBAExternalControllerButtonInputY:
            controllerButton = GBAControllerButtonStart;
            break;
            
        case GBAExternalControllerButtonInputLeft:
            controllerButton = GBAControllerButtonLeft;
            break;
            
        case GBAExternalControllerButtonInputRight:
            controllerButton = GBAControllerButtonRight;
            break;
            
        case GBAExternalControllerButtonInputUp:
            controllerButton = GBAControllerButtonUp;
            break;
            
        case GBAExternalControllerButtonInputDown:
            controllerButton = GBAControllerButtonDown;
            break;
            
        case GBAExternalControllerButtonInputLeftShoulder:
            controllerButton = GBAControllerButtonL;
            break;
            
        case GBAExternalControllerButtonInputLeftTrigger:
            controllerButton = GBAControllerButtonL;
            break;
            
        case GBAExternalControllerButtonInputRightShoulder:
            controllerButton = GBAControllerButtonR;
            break;
            
        case GBAExternalControllerButtonInputRightTrigger:
            controllerButton = GBAControllerButtonR;
            break;
    }
    
    return controllerButton;
}

@end
