//
//  GBABluetoothLinkManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/14/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBABluetoothLinkManager.h"
#import "GBAPeer_Private.h"
#import "GBAEmulatorCore.h"

#import <CoreBluetooth/CoreBluetooth.h>

// P1 = Peripheral = Server.
// P2, P3, P4 = Central = Client.
// This seems counter-intuitive, and in fact goes agains the spec, but this way the clients (P2, P3, P4) can search for servers (P1)

NSString *const GBALinkServiceUUID = @"8F2262D3-55A0-4E47-9A60-422F81C548F8";
NSString *const GBALinkInputDataCharacteristicUUID = @"3FC39C36-2D07-4E12-A83C-AAF9C8222FF8";
NSString *const GBALinkOutputDataCharacteristicUUID = @"BB844434-AD22-478B-8E0C-487BE8DE3DE3";
NSString *const GBALinkLatencyTestCharacteristicUUID = @"E5C9177D-FE00-428E-BAC8-45929F219D10";

@interface GBALinkManager ()

@property (readwrite, assign, nonatomic, getter=isLinkConnected) BOOL linkConnected;

@end

@interface GBABluetoothLinkManager () <CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>
{
    NSMutableArray *_connectedPeers;
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
@property (strong, nonatomic) dispatch_semaphore_t inputDataDispatchSemaphore;
@property (strong, nonatomic) NSMutableData *inputDataBuffer;
@property (strong, nonatomic) NSMutableData *outputDataBuffer;

@end

@implementation GBABluetoothLinkManager
@synthesize connectedPeers = _connectedPeers;
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
        
        _linkDispatchQueue = dispatch_queue_create("com.GBA4iOS.linkDispatchQueue", DISPATCH_QUEUE_CONCURRENT);
        
        _nearbyPeers = [NSMutableArray array];
        _connectedPeers = [NSMutableArray array];
        
        _inputDataBuffer = [NSMutableData data];
        _outputDataBuffer = [NSMutableData data];
    }
    
    return self;
}

#pragma mark - Transmitting Data -

- (NSInteger)sendData:(NSData *)data toPlayerAtIndex:(NSInteger)index
{
    [self.outputDataBuffer appendData:data];
    
    NSData *outputData = [self.outputDataBuffer copy]; // In case outputDataBuffer is modified
    
    BOOL success = YES;
    
    if (self.peerType == GBALinkPeerTypeClient)
    {
        GBAPeer *peer = nil;
        
        for (GBAPeer *p in [self.connectedPeers copy])
        {
            if (p.playerIndex == index)
            {
                peer = p;
            }
        }

        [(CBPeripheral *)peer.bluetoothPeer writeValue:outputData forCharacteristic:peer.inputDataCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
    else
    {
        success = [self.peripheralManager updateValue:outputData forCharacteristic:(CBMutableCharacteristic *)self.currentPeer.outputDataCharacteristic onSubscribedCentrals:nil];
    }
    
    if (success)
    {
        [self.outputDataBuffer replaceBytesInRange:NSMakeRange(0, outputData.length) withBytes:NULL length:0];
        return [outputData length];
    }
    
    return 0;
}

- (NSInteger)receiveData:(NSData **)data withMaxSize:(NSUInteger)maxSize fromPlayerAtIndex:(NSInteger)index
{
    __block NSRange range = NSMakeRange(0, 0);
    
    range = NSMakeRange(0, MIN(maxSize, self.inputDataBuffer.length));
    *data = [self.inputDataBuffer subdataWithRange:range];
    [self.inputDataBuffer replaceBytesInRange:range withBytes:NULL length:0];
    
    return range.length;
}

- (BOOL)waitForLinkDataWithTimeout:(NSTimeInterval)timeout
{
    if ([self.inputDataBuffer length] > 0)
    {
        return YES;
    }
    
    self.inputDataDispatchSemaphore = dispatch_semaphore_create(0);
    
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC);
    dispatch_semaphore_wait(self.inputDataDispatchSemaphore, DISPATCH_TIME_FOREVER);

    self.inputDataDispatchSemaphore = nil;
    
    return ([self.inputDataBuffer length] > 0);
}

- (void)didReceiveData:(NSData *)data
{
    [self.inputDataBuffer appendData:data];
    
    if (self.inputDataDispatchSemaphore)
    {
        dispatch_semaphore_signal(self.inputDataDispatchSemaphore);
    }
}

#pragma mark - Connecting -

- (void)didConnectPeer:(GBAPeer *)peer
{
    [_nearbyPeers removeObject:peer];
    [_connectedPeers addObject:peer];
    
    if ([self.delegate respondsToSelector:@selector(linkManager:didConnectPeer:)])
    {
        [self.delegate linkManager:self didConnectPeer:peer];
    }
    
    GBALinkPeerType peerType = (peer.playerIndex == 0) ? GBALinkPeerTypeClient : GBALinkPeerTypeServer; // If adding a peer with playerIndex == 0, then we are _not_ playerIndex == 0
    
    [[GBAEmulatorCore sharedCore] startLinkWithConnectionType:GBALinkConnectionTypeLinkCable peerType:peerType completion:^(BOOL success) {
        
        DLog(@"Success connecting? %d", success);
        
        [[GBALinkManager sharedManager] setLinkConnected:success];
        
    }];
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
        
    [self didConnectPeer:peer];
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
    if (self.currentPeer.name == nil)
    {
        self.currentPeer = [[GBAPeer alloc] init];
        self.currentPeer.identifier = [NSUUID UUID];
        
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
    }
    
    self.currentPeer.name = self.name;
    
    if (self.currentPeer.name == nil)
    {
        self.currentPeer.name = [[UIDevice currentDevice] name];
    }
    
    if (self.peripheralManager == nil)
    {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.linkDispatchQueue options:nil];
    }
    else
    {
        [self peripheralManager:self.peripheralManager didAddService:self.linkService error:nil];
    }
}

- (void)stopAdvertisingPeer
{
    [self.peripheralManager stopAdvertising];
    
    //self.currentPeer = nil;
    //[self.peripheralManager removeAllServices];
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

#pragma mark - GBCentralManagerDelegate (Client) -

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        DLog(@"Starting Scan...");
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:GBALinkServiceUUID]] options:nil];
    }
    else
    {
        DLog(@"Problem with central: %ld", (long)central.state);
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
        [_connectedPeers removeObject:peer];
        [_nearbyPeers addObject:peer];
        
        if ([self.delegate respondsToSelector:@selector(linkManager:didDisconnectPeer:error:)])
        {
            [self.delegate linkManager:self didDisconnectPeer:peer error:error];
        }
    }    
}

#pragma mark - CBPeripheralDelegate (Client) -

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
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:GBALinkOutputDataCharacteristicUUID]])
    {
        if ([characteristic.value length] == 4)
        {
            return;
        }
        
        [self didReceiveData:characteristic.value];
    }
}

#pragma mark - CBPeripheralManagerDelegate (Server) -

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state == CBPeripheralManagerStatePoweredOn)
    {
        DLog(@"Adding service %@...", self.linkService);
        [self.peripheralManager addService:self.linkService];
    }
    else
    {
        DLog(@"Problem with Peripheral Manager: %ld", (long)peripheral.state);
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
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:GBALinkOutputDataCharacteristicUUID]])
    {
        GBAPeer *peer = [[GBAPeer alloc] initWithBluetoothPeer:central];
        peer.playerIndex = 1;
        peer.state = GBAPeerStateConnected;
        
        [self didConnectPeer:peer];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    CBATTRequest *request = [requests firstObject];
    
    if ([request.characteristic.UUID isEqual:self.currentPeer.inputDataCharacteristic.UUID])
    {        
        [self didReceiveData:request.value];
        
        //[self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
        
        [self.peripheralManager updateValue:request.value forCharacteristic:(CBMutableCharacteristic *)self.currentPeer.outputDataCharacteristic onSubscribedCentrals:nil];
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
    
    for (GBAPeer *peer in self.connectedPeers)
    {
        if ([peer.identifier isEqual:bluetoothPeer.identifier])
        {
            return peer;
        }
    }
    
    return nil;
}

@end
