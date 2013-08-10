//
//  GBAEmulatorCore.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EAGLView.h"
#import "GBAController.h"

// Implements both GBAEmulatorCore AND EAGLView

@interface GBAEmulatorCore : NSObject

@property (readonly, strong, nonatomic) EAGLView *eaglView;
@property (copy, nonatomic) NSString *romFilepath;

+ (instancetype)sharedCore;

- (void)startEmulation;
- (void)pauseEmulation;
- (void)resumeEmulation;
- (void)endEmulation;

- (void)pressButtons:(NSSet *)buttons;
- (void)releaseButtons:(NSSet *)buttons;

@end