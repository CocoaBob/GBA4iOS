//
//  GBAEmulatorCore.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulatorCore.h"

NSString *const GBAROMDidSaveDataNotification = @"GBAROMDidSaveDataNotification";

@interface GBAEmulatorCore ()

@property (readwrite, strong, nonatomic) EAGLView *eaglView;

@end

@implementation GBAEmulatorCore

+ (instancetype)sharedCore {
    static GBAEmulatorCore *sharedCore = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCore = [[self alloc] init];
    });
    return sharedCore;
}

- (void)updateEAGLViewForSize:(CGSize)size screen:(UIScreen *)screen
{
    if (self.eaglView == nil)
    {
        // Create the OpenGL ES view
        UIView *view = [[EAGLView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        self.eaglView = view;
    }
    else
    {
        self.eaglView.frame = CGRectMake(0, 0, size.width, size.height);
        [self.eaglView.superview layoutIfNeeded];
    }
}

- (void)startEmulation
{
    
}

- (void)pauseEmulation
{
    
}

- (void)resumeEmulation
{
    
}

- (void)endEmulation
{
    
}

- (void)applyEmulationFilter:(GBAEmulationFilter)emulationFilter
{
    
}

- (void)writeSaveFileForCurrentROMToDisk
{
    
}

- (void)saveStateToFilepath:(NSString *)filepath
{
    
}

- (void)loadStateFromFilepath:(NSString *)filepath
{
    
}

- (BOOL)addCheat:(GBACheat *)cheat
{
    return YES;
}

- (void)enableCheat:(GBACheat *)cheat
{
    
}

- (void)disableCheat:(GBACheat *)cheat
{
    
}

- (BOOL)updateCheats
{
    return YES;
}

- (void)pressButtons:(NSSet *)buttons
{
    
}

- (void)releaseButtons:(NSSet *)buttons
{
    
}

- (void)startFastForwarding
{
    
}

- (void)stopFastForwarding
{
    
}

- (void)startServer
{
    
}

- (void)connectToServer
{
    
}

- (void)startConnection
{
    
}

- (void)startLinkWithConnectionType:(GBALinkConnectionType)connectionType peerType:(GBALinkPeerType)peerType completion:(void (^)(BOOL))completion {
    
}

- (void)stopLink {
    
}

bool useCustomSavePath();

@end
