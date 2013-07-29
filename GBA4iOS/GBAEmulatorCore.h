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
@property (readonly, copy, nonatomic) NSString *romFilepath;

- (instancetype)initWithROMFilepath:(NSString *)romFilepath;

- (void)start;

- (void)setSelectedButtons:(GBAControllerButton)buttons;

@end