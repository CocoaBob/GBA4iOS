//
//  GBAEmulatorScreen.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "EAGLView_Private.h"

@interface GBAEmulatorScreen : UIView

#if !(TARGET_IPHONE_SIMULATOR)
@property (strong, nonatomic) EAGLView *eaglView;
#else
@property (strong, nonatomic) UIView *eaglView;
#endif

@property (strong, nonatomic) AVPlayerLayer *introAnimationLayer;

@end
