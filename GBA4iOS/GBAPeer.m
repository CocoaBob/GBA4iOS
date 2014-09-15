//
//  GBAPeer.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/15/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAPeer_Private.h"

@import CoreBluetooth;

@implementation GBAPeer

- (instancetype)initWithBluetoothPeer:(CBPeer *)peer
{
    self = [super init];
    if (self)
    {
        _bluetoothPeer = peer;
        _playerIndex = -1;
        _identifier = [peer.identifier copy];
        
        if ([peer isKindOfClass:[CBPeripheral class]])
        {
            CBPeripheral *peripheral = (CBPeripheral *)peer;
            _name = [peripheral.name copy];
        }
    }
    
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GBAPeer class]])
    {
        return NO;
    }
    
    GBAPeer *peer = object;
    return [self.identifier isEqual:peer.identifier];
}

- (NSUInteger)hash
{
    return [self.identifier hash];
}

@end
