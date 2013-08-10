//
//  UITouch+ControllerButtons.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/9/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "UITouch+ControllerButtons.h"

#import <objc/runtime.h>

@implementation UITouch (ControllerButtons)
@dynamic controllerButtons;

- (void)setControllerButtons:(NSSet *)controllerButtons
{
    objc_setAssociatedObject(self, @selector(controllerButtons), controllerButtons, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSSet *)controllerButtons
{
    return objc_getAssociatedObject(self, @selector(controllerButtons));
}

@end
