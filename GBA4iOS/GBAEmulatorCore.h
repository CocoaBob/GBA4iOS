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
#import "GBACheat.h"

// Implements both GBAEmulatorCore AND EAGLView

@interface GBAEmulatorCore : NSObject

@property (readonly, strong, nonatomic) EAGLView *eaglView;
@property (copy, nonatomic) NSString *romFilepath;
@property (copy, nonatomic) NSString *cheatsDirectory;

+ (instancetype)sharedCore;

- (void)startEmulation;
- (void)pauseEmulation;
- (void)prepareToEnterBackground;
- (void)resumeEmulation;
- (void)endEmulation;

// Save States
- (void)saveStateToFilepath:(NSString *)filepath;
- (void)loadStateFromFilepath:(NSString *)filepath;

// Cheats
- (void)addCheat:(GBACheat *)cheat;
- (void)enableCheatAtIndex:(int)index;
- (void)disableCheatAtIndex:(int)index;

- (void)pressButtons:(NSSet *)buttons;
- (void)releaseButtons:(NSSet *)buttons;

@end