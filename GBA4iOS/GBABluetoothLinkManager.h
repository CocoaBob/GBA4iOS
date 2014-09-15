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

@class GBABluetoothLinkManager;
@class GBAPeer;

@protocol GBABluetoothLinkManagerDelegate <NSObject>

@optional

// Server
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didStartAdvertisingPeer:(GBAPeer *)peer;
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didFailToAdvertisePeer:(GBAPeer *)peer error:(NSError *)error;

// Client
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didDiscoverPeer:(GBAPeer *)peer;

- (void)linkManager:(GBABluetoothLinkManager *)linkManager didConnectPeer:(GBAPeer *)peer;
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didFailToConnectPeer:(GBAPeer *)peer error:(NSError *)error;
- (void)linkManager:(GBABluetoothLinkManager *)linkManager didDisconnectPeer:(GBAPeer *)peer error:(NSError *)error;

@end

@interface GBABluetoothLinkManager : NSObject

@property (weak, nonatomic) id<GBABluetoothLinkManagerDelegate> delegate;
@property (assign, nonatomic) GBALinkPeerType peerType;

@property (copy, nonatomic, readonly) NSArray *connectedPeers;
@property (copy, nonatomic, readonly) NSArray *nearbyPeers;

+ (instancetype)sharedManager;

- (void)startScanningForPeers;
- (void)stopScanningForPeers;
- (void)connectPeer:(GBAPeer *)peer;

- (void)startAdvertisingPeer;
- (void)stopAdvertisingPeer;

@end
