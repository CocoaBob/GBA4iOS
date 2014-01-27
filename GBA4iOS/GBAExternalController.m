//
//  GBAExternalController.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/22/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAExternalController_Private.h"
#import "GBAControllerSkin.h"
#import "GBASettingsViewController.h"

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

+ (void)registerControllerDefaults
{
    NSDictionary *controllerButtons = @{[GBAExternalController keyForButtonInput:GBAExternalControllerButtonInputA]: @(GBAControllerButtonA),
                                        [GBAExternalController keyForButtonInput:GBAExternalControllerButtonInputB]: @(GBAControllerButtonB),
                                        [GBAExternalController keyForButtonInput:GBAExternalControllerButtonInputX]: @(GBAControllerButtonSelect),
                                        [GBAExternalController keyForButtonInput:GBAExternalControllerButtonInputY]: @(GBAControllerButtonStart),
                                        [GBAExternalController keyForButtonInput:GBAExternalControllerButtonInputLeftTrigger]: @(GBAControllerButtonL),
                                        [GBAExternalController keyForButtonInput:GBAExternalControllerButtonInputRightTrigger]: @(GBAControllerButtonR)};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{GBASettingsExternalControllerButtonsKey: controllerButtons}];
}

+ (NSString *)keyForButtonInput:(GBAExternalControllerButtonInput)buttonInput
{
    NSString *string = @"";
    
    switch (buttonInput)
    {
        case GBAExternalControllerButtonInputA:
            string = @"A";
            break;
            
        case GBAExternalControllerButtonInputB:
            string = @"B";
            break;
            
        case GBAExternalControllerButtonInputX:
            string = @"X";
            break;
            
        case GBAExternalControllerButtonInputY:
            string = @"Y";
            break;
            
        case GBAExternalControllerButtonInputUp:
            string = @"Up";
            break;
            
        case GBAExternalControllerButtonInputDown:
            string = @"Down";
            break;
            
        case GBAExternalControllerButtonInputLeft:
            string = @"Left";
            break;
            
        case GBAExternalControllerButtonInputRight:
            string = @"Right";
            break;
            
        case GBAExternalControllerButtonInputLeftShoulder:
            string = @"L1";
            break;
            
        case GBAExternalControllerButtonInputLeftTrigger:
            string = @"L2";
            break;
            
        case GBAExternalControllerButtonInputRightShoulder:
            string = @"R1";
            break;
            
        case GBAExternalControllerButtonInputRightTrigger:
            string = @"R2";
            break;
    }
    
    return string;
}

#ifdef USE_POLLING

- (void)configureController
{
    __weak __typeof__(self) weakSelf = self;
    self.controller.controllerPausedHandler = ^(GCController *controller)
    {
        [weakSelf.delegate controllerInputDidPressMenuButton:weakSelf];
    };
}

#pragma mark - Update Controls

- (void)updateControllerInputs
{
    GCController *controller = self.controller;
    
    [self updateControllerButton:controller.gamepad.buttonA];
    [self updateControllerButton:controller.gamepad.buttonB];
    [self updateControllerButton:controller.gamepad.buttonX];
    [self updateControllerButton:controller.gamepad.buttonY];
    [self updateControllerButton:controller.gamepad.leftShoulder];
    [self updateControllerButton:controller.gamepad.rightShoulder];
    [self updateControllerButton:controller.extendedGamepad.leftTrigger];
    [self updateControllerButton:controller.extendedGamepad.rightTrigger];
    
    [self updateControllerDPad:controller.gamepad.dpad];
    [self updateControllerDPad:controller.extendedGamepad.leftThumbstick];
}

- (void)updateControllerButton:(GCControllerButtonInput *)button
{
    GBAExternalControllerButtonInput externalControllerButtonInput = [self externalControllerButtonInputForButton:button];
    
    BOOL previouslyPressed = [self.previousButtonStates[@(externalControllerButtonInput)] boolValue];
    
    if (previouslyPressed == (button.value > 0))
    {
        return;
    }
    
    GBAControllerButton controllerButton = [GBAExternalController controllerButtonForControllerButtonInput:externalControllerButtonInput];
    NSSet *set = [NSSet setWithObject:@(controllerButton)];
    
    if (button.value > 0)
    {
        [self.delegate controllerInput:self didPressButtons:set];
    }
    else
    {
        [self.delegate controllerInput:self didReleaseButtons:set];
    }
    
    self.previousButtonStates[@(externalControllerButtonInput)] = @(button.value > 0);
}


- (void)updateControllerDPad:(GCControllerDirectionPad *)dPad
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

/* Keeping all this code around in case Apple fixes the stupid delayed button bug, since it is much more efficient :( */

#else


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
    
    extendedGamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue)
    {
        [self controllerDPadDidChange:dpad];
    };
}

#pragma mark - Controls

- (void)controllerButtonInput:(GBAExternalControllerButtonInput)buttonInput wasPressed:(BOOL)pressed
{
    BOOL previouslyPressed = [self.previousButtonStates[@(buttonInput)] boolValue];
    
    GBAControllerButton controllerButton = [GBAExternalController controllerButtonForControllerButtonInput:buttonInput];
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

#endif

#pragma mark - Helper Methods

+ (GBAControllerButton)controllerButtonForControllerButtonInput:(GBAExternalControllerButtonInput)buttonInput
{
    GBAControllerButton controllerButton = 0;
    
    switch (buttonInput)
    {
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
            
        case GBAExternalControllerButtonInputRightShoulder:
            controllerButton = GBAControllerButtonR;
            break;
            
        default: {
            NSDictionary *buttonDictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:GBASettingsExternalControllerButtonsKey];
            NSString *buttonString = [GBAExternalController keyForButtonInput:buttonInput];
            controllerButton = [buttonDictionary[buttonString] integerValue];
            break;
        }
    }
    
    return controllerButton;
}

- (GBAExternalControllerButtonInput)externalControllerButtonInputForButton:(GCControllerButtonInput *)button
{
    GCController *controller = self.controller;
    
    GBAExternalControllerButtonInput externalControllerButtonInput = 0;
    
    if (button == controller.gamepad.buttonA)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputA;
    }
    else if (button == controller.gamepad.buttonB)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputB;
    }
    else if (button == controller.gamepad.buttonX)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputX;
    }
    else if (button == controller.gamepad.buttonY)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputY;
    }
    else if (button == controller.gamepad.leftShoulder)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputLeftShoulder;
    }
    else if (button == controller.gamepad.rightShoulder)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputRightShoulder;
    }
    else if (button == controller.extendedGamepad.leftTrigger)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputLeftTrigger;
    }
    else if (button == controller.extendedGamepad.rightTrigger)
    {
        externalControllerButtonInput = GBAExternalControllerButtonInputRightTrigger;
    }
    
    return externalControllerButtonInput;
}

@end
