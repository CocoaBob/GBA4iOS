//
//  GBAEmulatorCore.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#if !(TARGET_IPHONE_SIMULATOR)
#import "EAGLView.h"
#else
@compatibility_alias EAGLView UIView;
#endif

#import "GBAControllerSkin.h"
#import "GBACheat.h"
#import "GBAROM.h"

#import "GBALinkManager.h"

typedef NS_ENUM(NSInteger, GBAEmulationFilter)
{
    GBAEmulationFilterNone = 0,
    GBAEmulationFilterLinear = 1
};

// Implements both GBAEmulatorCore AND EAGLView

extern NSString *const GBAROMDidSaveDataNotification;

@class GBAEmulatorCore;

@protocol GBAEmulatorCoreDelegate <NSObject>

- (void)emulatorCore:(GBAEmulatorCore *)emulatorCore didEnableGyroscopeForROM:(GBAROM *)rom;

@end

@interface GBAEmulatorCore : NSObject

@property (readonly, strong, nonatomic) EAGLView *eaglView;
@property (strong, nonatomic) GBAROM *rom;
@property (weak, nonatomic) id<GBAEmulatorCoreDelegate> delegate;
@property (copy, nonatomic) NSString *customSavePath;

@property (assign, nonatomic, readonly, getter=isPaused) BOOL paused;

+ (instancetype)sharedCore;

- (void)updateEAGLViewForSize:(CGSize)size screen:(UIScreen *)screen;

- (void)startEmulation;
- (void)pauseEmulation;
- (void)resumeEmulation;
- (void)endEmulation;

- (void)applyEmulationFilter:(GBAEmulationFilter)emulationFilter;

// Saves
- (void)writeSaveFileForCurrentROMToDisk;

// Save States
- (void)saveStateToFilepath:(NSString *)filepath;
- (void)loadStateFromFilepath:(NSString *)filepath;

// Cheats
- (BOOL)addCheat:(GBACheat *)cheat;
// - (void)removeCheat:(GBACheat *)cheat; Call updateCheats instead
- (void)enableCheat:(GBACheat *)cheat;
- (void)disableCheat:(GBACheat *)cheat;
- (BOOL)updateCheats;

// Sustain Button
- (void)pressButtons:(NSSet *)buttons;
- (void)releaseButtons:(NSSet *)buttons;

// Fast Forward
- (void)startFastForwarding;
- (void)stopFastForwarding;

// Linking
- (void)startLinkWithConnectionType:(GBALinkConnectionType)connectionType peerType:(GBALinkPeerType)peerType completion:(void (^)(BOOL success))completion;
- (void)stopLink;

@end