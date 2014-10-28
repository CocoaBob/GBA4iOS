//
//  GBABluetoothLinkManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/14/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, GBALinkPeerType)
{
    GBALinkPeerTypeUnknown = 0,
    GBALinkPeerTypeClient  = 1,
    GBALinkPeerTypeServer  = 2,
};

typedef NS_ENUM(NSUInteger, GBALinkConnectionType)
{
    GBALinkConnectionTypeLinkCable        = 0,
    GBALinkConnectionTypeWirelessAdapter  = 1,
};

@class GBABluetoothLinkManager;
@class GBAPeer;

@protocol GBABluetoothLinkManagerDelegate <NSObject>

@optional

// Server
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didStartAdvertisingPeer:(GBAPeer *)peer;
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didFailToAdvertisePeer:(GBAPeer *)peer error:(NSError *)error;

// Client
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didDiscoverPeer:(GBAPeer *)peer;
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didFailToConnectPeer:(GBAPeer *)peer error:(NSError *)error;

// Both
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didConnectPeer:(GBAPeer *)peer;
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didDisconnectPeer:(GBAPeer *)peer error:(NSError *)error;

@end

@interface GBABluetoothLinkManager : NSObject

@property (weak, nonatomic) id<GBABluetoothLinkManagerDelegate> delegate;
@property (assign, nonatomic) GBALinkPeerType peerType;
@property (copy, nonatomic) NSString *name;
@property (assign, nonatomic, getter=isEnabled) BOOL enabled;
@property (readonly, assign, nonatomic, getter=isLinkConnected) BOOL linkConnected;

@property (copy, nonatomic, readonly) NSArray *connectedPeers;
@property (copy, nonatomic, readonly) NSArray *nearbyPeers;

+ (instancetype)sharedManager;

- (void)startScanningForPeers;
- (void)stopScanningForPeers;
- (void)connectPeer:(GBAPeer *)peer;

- (void)startAdvertisingPeer;
- (void)stopAdvertisingPeer;

- (NSInteger)sendData:(NSData *)data toPlayerAtIndex:(NSInteger)index;
- (NSInteger)receiveData:(NSData **)data withMaxSize:(NSUInteger)maxSize fromPlayerAtIndex:(NSInteger)index;

- (BOOL)waitForLinkDataWithTimeout:(NSTimeInterval)timeout;

@end
