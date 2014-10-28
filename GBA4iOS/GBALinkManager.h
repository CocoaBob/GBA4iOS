//
//  GBALinkManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 4/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GBABluetoothLinkManager.h"

// Can't use @import in C++ linked code :(
#import <MultipeerConnectivity/MultipeerConnectivity.h>

extern NSString *const GBALinkSessionServiceType;

@class GBALinkManager;

@protocol GBALinkManagerDelegate <NSObject>

@optional
- (void)linkManager:(GBALinkManager *)linkManager peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state;

@end

@interface GBALinkManager : NSObject

@property (weak, nonatomic) id<GBALinkManagerDelegate> delegate;
@property (readonly, assign, nonatomic) GBALinkPeerType peerType;
@property (readonly, assign, nonatomic, getter=isLinkConnected) BOOL linkConnected;

@property (readonly, strong, nonatomic) MCSession *session;

+ (instancetype)sharedManager;

- (void)start;
- (void)stop;

- (NSInteger)sendData:(const char *)data withSize:(size_t)size toPlayerAtIndex:(NSInteger)index;
- (NSInteger)receiveData:(char *)data withMaxSize:(size_t)maxSize fromPlayerAtIndex:(NSInteger)index;

- (BOOL)waitForLinkDataWithTimeout:(NSTimeInterval)timeout;
- (BOOL)hasLinkDataAvailable:(int *)index;

@end
