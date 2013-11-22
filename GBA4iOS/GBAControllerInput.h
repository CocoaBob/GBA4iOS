//
//  GBAControllerInput.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/22/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol GBAControllerInputDelegate <NSObject>

- (void)controllerInput:(id)controllerInput didPressButtons:(NSSet *)buttons;
- (void)controllerInput:(id)controllerInput didReleaseButtons:(NSSet *)buttons;
- (void)controllerInputDidPressMenuButton:(id)controllerInput;

@end

@protocol GBAControllerInput <NSObject>

@property (weak, nonatomic) id<GBAControllerInputDelegate> delegate;

@end
