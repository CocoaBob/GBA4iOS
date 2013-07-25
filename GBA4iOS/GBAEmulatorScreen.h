//
//  GBAEmulatorScreen.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "EAGLView_Private.h"

@interface GBAEmulatorScreen : UIView

@property (strong, nonatomic) EAGLView *eaglView;

@end
