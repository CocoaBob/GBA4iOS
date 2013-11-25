//
//  GBAEmulatorCore.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EAGLView.h"
#import "GBAControllerSkin.h"
#import "GBACheat.h"
#import "GBAROM.h"

// Implements both GBAEmulatorCore AND EAGLView

#if TARGET_IPHONE_SIMULATOR

#error This target cannot be compiled for the simulator. To compile for simulator, use the GBA4iOS-Simulator target.

#endif

extern NSString *const GBAROMDidSaveDataNotification;

@interface GBAEmulatorCore : NSObject

@property (readonly, strong, nonatomic) EAGLView *eaglView;
@property (strong, nonatomic) GBAROM *rom;

+ (instancetype)sharedCore;

- (void)resetEAGLView;
- (void)updateEAGLViewForSize:(CGSize)size screen:(UIScreen *)screen;

- (void)startEmulation;
- (void)pauseEmulation;
- (void)resumeEmulation;
- (void)endEmulation;

// Save States
- (void)saveStateToFilepath:(NSString *)filepath;
- (void)loadStateFromFilepath:(NSString *)filepath;

// Cheats
- (BOOL)addCheat:(GBACheat *)cheat;
// - (void)removeCheat:(GBACheat *)cheat; Call updateCheats instead
- (void)enableCheat:(GBACheat *)cheat;
- (void)disableCheat:(GBACheat *)cheat;
- (BOOL)updateCheats;

- (void)pressButtons:(NSSet *)buttons;
- (void)releaseButtons:(NSSet *)buttons;

@end