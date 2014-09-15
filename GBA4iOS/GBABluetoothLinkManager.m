//
//  GBABluetoothLinkManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/14/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBABluetoothLinkManager.h"
#import "GBAPeer_Private.h"

@import CoreBluetooth;

// P1 = Peripheral = Server.
// P2, P3, P4 = Central = Client.
// This seems counter-intuitive, and in fact goes agains the spec, but this way the clients (P2, P3, P4) can search for servers (P1)

NSString *const GBALinkServiceUUID = @"8F2262D3-55A0-4E47-9A60-422F81C548F8";
NSString *const GBALinkInputDataCharacteristicUUID = @"3FC39C36-2D07-4E12-A83C-AAF9C8222FF8";
NSString *const GBALinkOutputDataCharacteristicUUID = @"BB844434-AD22-478B-8E0C-487BE8DE3DE3";

@interface GBABluetoothLinkManager () <CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>
{
    NSMutableArray *_nearbyPeers;
    NSMutableArray *_connectedPeers;
}

// Server (P1)
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) GBAPeer *currentPeer;

// Client (P2, P3, P4)
@property (strong, nonatomic) CBCentralManager *centralManager;

// Misc.
@property (strong, nonatomic) dispatch_queue_t linkDispatchQueue;

@end

@implementation GBABluetoothLinkManager
@synthesize nearbyPeers = _nearbyPeers;
@synthesize connectedPeers = _connectedPeers;

+ (instancetype)sharedManager
{
    static GBABluetoothLinkManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _peerType = GBALinkPeerTypeUnknown;
        
        _linkDispatchQueue = dispatch_queue_create("com.GBA4iOS.linkDispatchQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

#pragma mark - Client -

- (void)startScanningForPeers
{
    if (self.peerType != GBALinkPeerTypeClient)
    {
        DLog(@"Error Scanning: Only Clients may scan for peers.");
        return;
    }
    
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:GBALinkServiceUUID]] options:nil];
}

- (void)stopScanningForPeers
{
    [self.centralManager stopScan];
}

- (void)connectPeer:(GBAPeer *)peer
{
    [self.centralManager connectPeripheral:(CBPeripheral *)peer.bluetoothPeer options:nil];
}

- (void)didConnectPeripheral:(CBPeripheral *)peripheral
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    peer.playerIndex = 0;
    
    [_nearbyPeers removeObject:peer];
    [_connectedPeers addObject:peer];
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didConnectPeer:)])
    {
        [self.delegate linkManager:self didConnectPeer:peer];
    }
}

- (void)didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didFailToConnectPeer:error:)])
    {
        [self.delegate linkManager:self didFailToConnectPeer:peer error:error];
    }
}

#pragma mark - Server -

- (void)startAdvertisingPeer
{
    self.currentPeer = [[GBAPeer alloc] init];
    self.currentPeer.name = [[UIDevice currentDevice] name];
    self.currentPeer.identifier = [NSUUID UUID];
    
    CBMutableCharacteristic *inputDataCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:GBALinkInputDataCharacteristicUUID]
                                                                                          properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse
                                                                                               value:nil
                                                                                         permissions:CBAttributePermissionsWriteable];
    
    CBMutableCharacteristic *outputDataCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:GBALinkOutputDataCharacteristicUUID]
                                                                                           properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify
                                                                                                value:nil
                                                                                          permissions:CBAttributePermissionsReadable];
    
    CBMutableService *linkService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:GBALinkServiceUUID] primary:YES];
    linkService.characteristics = @[inputDataCharacteristic, outputDataCharacteristic];
    
    [self.peripheralManager addService:linkService];
}

- (void)stopAdvertisingPeer
{
    self.currentPeer = nil;
    [self.peripheralManager removeAllServices];
}

- (void)didStartAdvertisingPeer
{
    if ([self.delegate respondsToSelector:@selector(linkManager:didStartAdvertisingPeer:)])
    {
        [self.delegate linkManager:self didStartAdvertisingPeer:self.currentPeer];
    }
}

- (void)didFailToStartAdvertisingPeerWithError:(NSError *)error
{
    [self stopAdvertisingPeer];
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didFailToAdvertisePeer:error:)])
    {
        [self.delegate linkManager:self didFailToAdvertisePeer:self.currentPeer error:error];
    }
}

#pragma mark - GBCentralManagerDelegate -

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    DLog(@"Started Central Manager!");
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    
    if (peer == nil)
    {
        peer = [[GBAPeer alloc] initWithBluetoothPeer:peripheral];
        
        [_nearbyPeers addObject:peer];
        
        if ([self.delegate respondsToSelector:@selector(linkManager:didDiscoverPeer:)])
        {
            [self.delegate linkManager:self didDiscoverPeer:peer];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    peripheral.delegate = self;
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self didFailToConnectPeripheral:peripheral error:error];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    
    if ([_connectedPeers containsObject:peer])
    {
        [_connectedPeers removeObject:peer];
        [_nearbyPeers addObject:peer];
        
        if ([self.delegate respondsToSelector:@selector(linkManager:didDisconnectPeer:error:)])
        {
            [self.delegate linkManager:self didDisconnectPeer:peer error:error];
        }
    }    
}

#pragma mark - CBPeripheralDelegate -

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        [self didFailToConnectPeripheral:peripheral error:error];
        [self.centralManager cancelPeripheralConnection:peripheral];
        
        return;
    }
    
    CBService *linkService = nil;
    
    for (CBService *service in peripheral.services)
    {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:GBALinkServiceUUID]])
        {
            linkService = service;
            break;
        }
    }
    
    [peripheral discoverCharacteristics:@[GBALinkInputDataCharacteristicUUID, GBALinkOutputDataCharacteristicUUID] forService:linkService];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        [self didFailToConnectPeripheral:peripheral error:error];
        [self.centralManager cancelPeripheralConnection:peripheral];
        
        return;
    }
    
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:GBALinkInputDataCharacteristicUUID]])
        {
            peer.inputDataCharacteristic = characteristic;
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:GBALinkOutputDataCharacteristicUUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            peer.outputDataCharacteristic = characteristic;
        }
    }
    
    [self didConnectPeripheral:peripheral];
}

#pragma mark - CBPeripheralManagerDelegate -

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    DLog(@"Started Peripheral Manager!");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        [self didFailToStartAdvertisingPeerWithError:error];
        return;
    }
    
    [peripheral startAdvertising:@{CBAdvertisementDataLocalNameKey: self.currentPeer.name,
                                   CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:GBALinkInputDataCharacteristicUUID], [CBUUID UUIDWithString:GBALinkOutputDataCharacteristicUUID]]}];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (error)
    {
        [self didFailToStartAdvertisingPeerWithError:error];
        return;
    }
    
    [self didStartAdvertisingPeer];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    //[peripheral setDesiredConnectionLatency:CBPeripheralManagerConnectionLatencyLow forCentral:central];
    DLog(@"Central subscribed: %@", central);
}

#pragma mark - Helper Methods -

- (GBAPeer *)peerForBluetoothPeer:(CBPeer *)bluetoothPeer
{
    for (GBAPeer *peer in self.nearbyPeers)
    {
        if ([peer.identifier isEqual:bluetoothPeer.identifier])
        {
            return peer;
        }
    }
    
    for (GBAPeer *peer in self.connectedPeers)
    {
        if ([peer.identifier isEqual:bluetoothPeer.identifier])
        {
            return peer;
        }
    }
    
    return nil;
}

#pragma mark - Getters/Setters -

- (void)setPeerType:(GBALinkPeerType)peerType
{
    if (_peerType == peerType)
    {
        return;
    }
    
    switch (peerType)
    {
        case GBALinkPeerTypeServer:
            _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.linkDispatchQueue options:nil];
            break;
            
        case GBALinkPeerTypeClient:
            _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.linkDispatchQueue options:nil];
            break;
            
        case GBALinkPeerTypeUnknown:
            break;
    }
}

@end
