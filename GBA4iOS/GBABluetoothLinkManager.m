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
NSString *const GBALinkLatencyTestCharacteristicUUID = @"E5C9177D-FE00-428E-BAC8-45929F219D10";

@interface GBABluetoothLinkManager () <CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>
{
    NSMutableArray *_nearbyPeers;
}

// Server (P1)
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableService *linkService;
@property (strong, nonatomic) GBAPeer *currentPeer;

// Client (P2, P3, P4)
@property (strong, nonatomic) CBCentralManager *centralManager;

// Misc.
@property (strong, nonatomic) dispatch_queue_t linkDispatchQueue;

@end

@implementation GBABluetoothLinkManager
@synthesize nearbyPeers = _nearbyPeers;

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
        _nearbyPeers = [NSMutableArray array];
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
    
    if (self.centralManager == nil)
    {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.linkDispatchQueue options:nil];
    }
    else
    {
        [self centralManagerDidUpdateState:self.centralManager];
    }
}

- (void)stopScanningForPeers
{
    [self.centralManager stopScan];
    [_nearbyPeers removeAllObjects];
}

- (void)connectPeer:(GBAPeer *)peer
{
    peer.state = GBAPeerStateConnecting;
    [self.centralManager connectPeripheral:(CBPeripheral *)peer.bluetoothPeer options:nil];
}

- (void)didConnectPeripheral:(CBPeripheral *)peripheral
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    peer.playerIndex = 0;
    peer.state = GBAPeerStateConnected;
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didConnectPeer:)])
    {
        [self.delegate linkManager:self didConnectPeer:peer];
    }
}

- (void)didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    peer.state = GBAPeerStateDisconnected;
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didFailToConnectPeer:error:)])
    {
        [self.delegate linkManager:self didFailToConnectPeer:peer error:error];
    }
}

#pragma mark - Server -

- (void)startAdvertisingPeer
{
    self.currentPeer = [[GBAPeer alloc] init];
    self.currentPeer.name = self.name;
    self.currentPeer.identifier = [NSUUID UUID];
    
    if (self.currentPeer.name == nil)
    {
        self.currentPeer.name = [[UIDevice currentDevice] name];
    }
    
    CBMutableCharacteristic *inputDataCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:GBALinkInputDataCharacteristicUUID]
                                                                                          properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse
                                                                                               value:nil
                                                                                         permissions:CBAttributePermissionsWriteable];
    
    CBMutableCharacteristic *outputDataCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:GBALinkOutputDataCharacteristicUUID]
                                                                                           properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify
                                                                                                value:nil
                                                                                          permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic *latencyTestCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:GBALinkLatencyTestCharacteristicUUID]
                                                                                            properties:(CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse | CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify)
                                                                                                 value:nil
                                                                                           permissions:CBAttributePermissionsWriteable | CBAttributePermissionsReadable];
    
    self.currentPeer.inputDataCharacteristic = inputDataCharacteristic;
    self.currentPeer.outputDataCharacteristic = outputDataCharacteristic;
    self.currentPeer.latencyTestCharacteristic = latencyTestCharacteristic;
    
    self.linkService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:GBALinkServiceUUID] primary:YES];
    self.linkService.characteristics = @[inputDataCharacteristic, outputDataCharacteristic, latencyTestCharacteristic];
    
    if (self.peripheralManager == nil)
    {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.linkDispatchQueue options:nil];
    }
    else
    {
        [self peripheralManagerDidUpdateState:self.peripheralManager];
    }
}

- (void)stopAdvertisingPeer
{
    [self.peripheralManager stopAdvertising];
    
    self.currentPeer = nil;
    [self.peripheralManager removeAllServices];
}

- (void)didStartAdvertisingPeer
{
    DLog(@"Did start advertising %@", self.currentPeer.name);
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didStartAdvertisingPeer:)])
    {
        [self.delegate linkManager:self didStartAdvertisingPeer:self.currentPeer];
    }
}

- (void)didFailToStartAdvertisingPeerWithError:(NSError *)error
{
    DLog(@"Did fail to start advertising %@", self.currentPeer.name);
    ELog(error);
    
    [self stopAdvertisingPeer];
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didFailToAdvertisePeer:error:)])
    {
        [self.delegate linkManager:self didFailToAdvertisePeer:self.currentPeer error:error];
    }
}

#pragma mark - GBCentralManagerDelegate -

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        DLog(@"Starting Scan...");
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:GBALinkServiceUUID]] options:nil];
    }
    else
    {
        DLog(@"Problem with central: %ld", central.state);
    }
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    
    if (peer == nil)
    {
        // Get notified when they update their name
        peripheral.delegate = self;
        
        peer = [[GBAPeer alloc] initWithBluetoothPeer:peripheral];
        
        [_nearbyPeers addObject:peer];
        
        if ([self.delegate respondsToSelector:@selector(linkManager:didDiscoverPeer:)])
        {
            [self.delegate linkManager:self didDiscoverPeer:peer];
        }
    }
    else if (![peer.name isEqualToString:peripheral.name])
    {
        DLog(@"Updated Peer Name: %@", peripheral.name);
        
        peer.name = peripheral.name;
        
        if ([self.delegate respondsToSelector:@selector(linkManager:didDiscoverPeer:)])
        {
            [self.delegate linkManager:self didDiscoverPeer:peer];
        }
    }
        
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self didFailToConnectPeripheral:peripheral error:error];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    
    if (peer.state == GBAPeerStateConnected)
    {
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
    
    [peripheral discoverCharacteristics:nil forService:linkService];
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
        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:GBALinkOutputDataCharacteristicUUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            peer.outputDataCharacteristic = characteristic;
        }
        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:GBALinkLatencyTestCharacteristicUUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            peer.latencyTestCharacteristic = characteristic;
        }
    }
    
    [self didConnectPeripheral:peripheral];
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    DLog(@"Updated Peer Name: %@", peripheral.name);
    
    GBAPeer *peer = [self peerForBluetoothPeer:peripheral];
    peer.name = peripheral.name;
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didDiscoverPeer:)])
    {
        [self.delegate linkManager:self didDiscoverPeer:peer];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        ELog(error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:GBALinkLatencyTestCharacteristicUUID]])
    {
        CFTimeInterval previousTime;
        [characteristic.value getBytes:(uint8_t *)&previousTime length:sizeof(previousTime)];
        
        DLog(@"Latency: %gms", ((CACurrentMediaTime() - previousTime) * 1000) / 2);
    }
}

#pragma mark - CBPeripheralManagerDelegate -

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state == CBPeripheralManagerStatePoweredOn)
    {
        DLog(@"Adding service %@...", self.linkService);
        [self.peripheralManager addService:self.linkService];
    }
    else
    {
        DLog(@"Problem with Peripheral Manager: %ld", peripheral.state);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        [self didFailToStartAdvertisingPeerWithError:error];
        return;
    }
    
    [peripheral startAdvertising:@{CBAdvertisementDataLocalNameKey: self.currentPeer.name, CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:GBALinkServiceUUID]]}];
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
    [peripheral setDesiredConnectionLatency:CBPeripheralManagerConnectionLatencyLow forCentral:central];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    CBATTRequest *request = [requests firstObject];
    
    if ([request.characteristic.UUID isEqual:self.currentPeer.latencyTestCharacteristic.UUID])
    {
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
        
        [self.peripheralManager updateValue:request.value forCharacteristic:(CBMutableCharacteristic *)self.currentPeer.latencyTestCharacteristic onSubscribedCentrals:nil];
    }
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
    
    return nil;
}

- (void)testLatency
{
    if (self.peerType != GBALinkPeerTypeClient)
    {
        DLog(@"Error Scanning: Only Clients may test latency.");
        return;
    }
    
    CFTimeInterval currentTime = CACurrentMediaTime();
    NSData *data = [NSData dataWithBytes:&currentTime length:sizeof(currentTime)];
    
    GBAPeer *peer = [self.nearbyPeers firstObject];
    
    [(CBPeripheral *)peer.bluetoothPeer writeValue:data forCharacteristic:peer.latencyTestCharacteristic type:CBCharacteristicWriteWithResponse];
}

@end
