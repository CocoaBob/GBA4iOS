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

@property (strong, nonatomic) NSMutableDictionary *previousButtonStates; // Don't use controller snapshots cause we only want to update individual buttons each time

@end

@implementation GBAExternalController

- (instancetype)initWithController:(GCController *)controller
{
    self = [super init];
    if (self)
    {
        _controller = controller;
        
        _previousButtonStates = [NSMutableDictionary dictionary];
        
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
        [self controllerButtonInput:GBAExternalControllerButtonInputA wasPressed:pressed];
    };
    
    gamepad.buttonB.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputB wasPressed:pressed];
    };
    
    gamepad.buttonX.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputX wasPressed:pressed];
    };
    
    gamepad.buttonY.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputY wasPressed:pressed];
    };
    
    gamepad.leftShoulder.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputLeftShoulder wasPressed:pressed];
    };
    
    gamepad.rightShoulder.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputRightShoulder wasPressed:pressed];
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
        [self controllerButtonInput:GBAExternalControllerButtonInputLeftTrigger wasPressed:pressed];
    };
    
    extendedGamepad.rightTrigger.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed)
    {
        [self controllerButtonInput:GBAExternalControllerButtonInputRightTrigger wasPressed:pressed];
    };
}

#pragma mark - Controls

- (void)controllerButtonInput:(GBAExternalControllerButtonInput)buttonInput wasPressed:(BOOL)pressed
{
    BOOL previouslyPressed = [self.previousButtonStates[@(buttonInput)] boolValue];
    
    GBAControllerButton controllerButton = [self controllerButtonForControllerButtonInput:buttonInput];
    NSSet *set = [NSSet setWithObject:@(controllerButton)];
    
    if (pressed && !previouslyPressed)
    {
        [self.delegate controllerInput:self didPressButtons:set];
    }
    else if (!pressed && previouslyPressed)
    {
        [self.delegate controllerInput:self didReleaseButtons:set];
    }
    
    self.previousButtonStates[@(buttonInput)] = @(pressed);
}

- (void)controllerDPadDidChange:(GCControllerDirectionPad *)dPad
{
    NSMutableSet *pressedButtons = [NSMutableSet set];
    NSMutableSet *releasedButtons = [NSMutableSet set];
    
    // Up
    BOOL previouslyPressedUp = [self.previousButtonStates[@(GBAExternalControllerButtonInputUp)] boolValue];
    if ([dPad.up isPressed] && !previouslyPressedUp)
    {
        [pressedButtons addObject:@(GBAControllerButtonUp)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputUp)] = @(dPad.up.pressed);
    }
    else if (![dPad.up isPressed] && previouslyPressedUp)
    {
        [releasedButtons addObject:@(GBAControllerButtonUp)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputUp)] = @(dPad.up.pressed);
    }
    
    // Down
    BOOL previouslyPressedDown = [self.previousButtonStates[@(GBAExternalControllerButtonInputDown)] boolValue];
    if ([dPad.down isPressed] && !previouslyPressedDown)
    {
        [pressedButtons addObject:@(GBAControllerButtonDown)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputDown)] = @(dPad.down.pressed);
    }
    else if (![dPad.down isPressed] && previouslyPressedDown)
    {
        [releasedButtons addObject:@(GBAControllerButtonDown)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputDown)] = @(dPad.down.pressed);
    }
    
    // Left
    BOOL previouslyPressedLeft = [self.previousButtonStates[@(GBAExternalControllerButtonInputLeft)] boolValue];
    if ([dPad.left isPressed] && !previouslyPressedLeft)
    {
        [pressedButtons addObject:@(GBAControllerButtonLeft)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputLeft)] = @(dPad.left.pressed);
    }
    else if (![dPad.left isPressed] && previouslyPressedLeft)
    {
        [releasedButtons addObject:@(GBAControllerButtonLeft)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputLeft)] = @(dPad.left.pressed);
    }
    
    // Right
    BOOL previouslyPressedRight = [self.previousButtonStates[@(GBAExternalControllerButtonInputRight)] boolValue];
    if ([dPad.right isPressed] && !previouslyPressedRight)
    {
        [pressedButtons addObject:@(GBAControllerButtonRight)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputRight)] = @(dPad.right.pressed);
    }
    else if (![dPad.right isPressed] && previouslyPressedRight)
    {
        [releasedButtons addObject:@(GBAControllerButtonRight)];
        self.previousButtonStates[@(GBAExternalControllerButtonInputRight)] = @(dPad.right.pressed);
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
            controllerButton = GBAControllerButtonB;
            break;
            
        case GBAExternalControllerButtonInputB:
            controllerButton = GBAControllerButtonA;
            break;
            
        case GBAExternalControllerButtonInputX:
            controllerButton = GBAControllerButtonSelect;
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
