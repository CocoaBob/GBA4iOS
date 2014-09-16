//
//  GBALinkManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 4/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBALinkManager.h"

#import "UIAlertView+RSTAdditions.h"
#import "MCPeerID+Conveniences.h"

NSString *const GBALinkSessionServiceType = @"gba4ios-link";

@interface GBALinkManager () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, NSStreamDelegate>
{
    BOOL _testingLatency;
}

@property (readwrite, assign, nonatomic) GBALinkPeerType peerType;

@property (strong, nonatomic) MCNearbyServiceAdvertiser *nearbyServiceAdvertiser;
@property (strong, nonatomic) MCNearbyServiceBrowser *nearbyServiceBrowser;

@property (strong, nonatomic) NSMutableDictionary *outputStreams;
@property (strong, nonatomic) NSMutableDictionary *inputStreams;

@end

@implementation GBALinkManager

+ (instancetype)sharedManager
{
    static GBALinkManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        MCPeerID *peerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
        
        _session = ({
            MCSession *session = [[MCSession alloc] initWithPeer:peerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
            session.delegate = self;
            session;
        });
        
        _nearbyServiceAdvertiser = ({
            MCNearbyServiceAdvertiser *nearbyServiceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:peerID discoveryInfo:nil serviceType:GBALinkSessionServiceType];
            nearbyServiceAdvertiser.delegate = self;
            nearbyServiceAdvertiser;
        });
        
        _outputStreams = [NSMutableDictionary dictionary];
        _inputStreams = [NSMutableDictionary dictionary];
    }
    
    return self;
}

#pragma mark - Linking

- (void)start
{
    [self.nearbyServiceAdvertiser startAdvertisingPeer];
}

- (void)stop
{
    [self.nearbyServiceAdvertiser stopAdvertisingPeer];
}

- (void)sendPeerType:(GBALinkPeerType)peerType toPeer:(MCPeerID *)peerID
{
    NSData *data = [NSData dataWithBytes:&peerType length:sizeof(peerType)];
    [self.session sendData:data toPeers:@[peerID] withMode:MCSessionSendDataReliable error:nil];
}

#pragma mark - Streaming Data -

- (NSInteger)sendData:(const char *)data withSize:(size_t)size toPlayerAtIndex:(NSInteger)index
{
    if (self.peerType == GBALinkPeerTypeServer)
    {
        index--;
    }
    
    MCPeerID *peerID = [self.session connectedPeers][index];
    NSOutputStream *outputStream = self.outputStreams[peerID];
    
    NSInteger bytesWritten = [outputStream write:(const uint8_t *)data maxLength:size];
    
    return bytesWritten;
}

- (NSInteger)receiveData:(char *)data withMaxSize:(size_t)maxSize fromPlayerAtIndex:(NSInteger)index
{
    if (self.peerType == GBALinkPeerTypeServer)
    {
        index--;
    }
    
    MCPeerID *peerID = [self.session connectedPeers][index];
    NSInputStream *inputStream = self.inputStreams[peerID];
    
    if (![inputStream hasBytesAvailable])
    {
        return 0;
    }
    
    NSInteger bytesRead = [inputStream read:(uint8_t *)data maxLength:maxSize];
    
    return bytesRead;
}

- (BOOL)waitForLinkDataWithTimeout:(NSTimeInterval)timeout
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    NSArray *inputStreams = [self.inputStreams allValues];
    
    while (![self hasBytesAvailableFromInputStreams:inputStreams]);
    
    if (![self hasBytesAvailableFromInputStreams:inputStreams])
    {
       DLog(@"Timeout");
    }
    
    return [self hasBytesAvailableFromInputStreams:inputStreams];
}

- (BOOL)hasBytesAvailableFromInputStreams:(NSArray *)inputStreams
{
    for (NSInputStream *inputStream in inputStreams)
    {
        if ([inputStream hasBytesAvailable])
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Latency -

- (void)testLatency
{
    _testingLatency = YES;
    
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    NSData *data = [NSData dataWithBytes:&currentTime length:sizeof(currentTime)];
    
    [self.outputStreams enumerateKeysAndObjectsUsingBlock:^(MCPeerID *peerID, NSOutputStream *outputstream, BOOL *stop) {
        
        [self sendLatencyData:data toPeer:peerID];
        
    }];
}

- (void)sendLatencyData:(NSData *)data toPeer:(MCPeerID *)peerID
{
    NSInteger bytesToStream = [data length];
    
    NSOutputStream *outputStream = self.outputStreams[peerID];
    
    NSInteger bytesWritten = [outputStream write:[data bytes] maxLength:bytesToStream];
    
    if (bytesWritten < 0)
    {
        DLog(@"Error streaming bytes");
    }
    
    //DLog(@"Wrote %li bytes", bytesWritten);
    
    //[self.session sendData:data toPeers:@[peerID] withMode:MCSessionSendDataUnreliable error:nil];
}

- (void)receiveLatencyData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    if (!_testingLatency)
    {
        [self sendLatencyData:data toPeer:peerID];
    }
    else
    {
        _testingLatency = NO;
        
        CFAbsoluteTime previousTime;
        [data getBytes:(uint8_t *)&previousTime length:sizeof(previousTime)];
        
        DLog(@"Latency: %gms", ((CFAbsoluteTimeGetCurrent() - previousTime) * 1000) / 2);
    }
}


- (void)receiveLatencyDataFromInputStream:(NSInputStream *)inputStream
{
    CFAbsoluteTime previousTime;
    NSInteger bytesRead = [inputStream read:(uint8_t *)&previousTime maxLength:sizeof(previousTime)];
    
    if (_testingLatency)
    {
        _testingLatency = NO;
        DLog(@"Latency: %gms", ((CFAbsoluteTimeGetCurrent() - previousTime) * 1000) / 2);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Latency Test" message:[NSString stringWithFormat:@"%gms", ((CFAbsoluteTimeGetCurrent() - previousTime) * 1000) / 2] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        });
    }
    else
    {
        NSData *data = [NSData dataWithBytes:&previousTime length:sizeof(previousTime)];
        
        [self.outputStreams enumerateKeysAndObjectsUsingBlock:^(MCPeerID *peer, NSOutputStream *outputstream, BOOL *stop) {
            
            [self sendLatencyData:data toPeer:peer];
            
        }];
    }
}

#pragma mark - MCNearbyServiceAdvertiserDelagate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession *))invitationHandler
{
    if (self.peerType == GBALinkPeerTypeUnknown)
    {
        self.peerType = GBALinkPeerTypeClient;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSString *title = [NSString stringWithFormat:@"%@ %@", peerID.displayName, NSLocalizedString(@"would like to link with you.", @"")];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Decline", @"")
                                              otherButtonTitles:NSLocalizedString(@"Accept", @""), nil];
        [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 0)
            {
                invitationHandler(NO, self.session);
            }
            else
            {
                invitationHandler(YES, self.session);
            }
        }];
        
    });
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    ELog(error);
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    peerID.rst_state = state;
    
    if (state == MCSessionStateConnected)
    {
        if (self.peerType == GBALinkPeerTypeClient)
        {
            GBALinkPeerType peerType = GBALinkPeerTypeUnknown;
            
            if ([[session connectedPeers] count] == 1)
            {
                peerType = GBALinkPeerTypeServer;
            }
            else
            {
                peerType = GBALinkPeerTypeClient;
            }
            
            [self sendPeerType:peerType toPeer:peerID];
        }
        
        if (![self.outputStreams objectForKey:peerID])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                NSError *error = nil;
                NSOutputStream *outputStream = [session startStreamWithName:[[UIDevice currentDevice] name] toPeer:peerID error:&error];
                
                if (error)
                {
                    ELog(error);
                }
                
                outputStream.delegate = self;
                
                [outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
                [outputStream open];
                
                self.outputStreams[peerID] = outputStream;
                
            });
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(linkManager:peer:didChangeState:)])
    {
        [self.delegate linkManager:self peer:peerID didChangeState:state];
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    GBALinkPeerType peerType = GBALinkPeerTypeUnknown;
    [data getBytes:&peerType length:sizeof(peerType)];
    
    if (self.peerType == GBALinkPeerTypeUnknown)
    {
        self.peerType = peerType;
        return;
    }
    
    [self receiveLatencyData:data fromPeer:peerID];
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (![self.inputStreams objectForKey:peerID])
        {
            stream.delegate = self;
            [stream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            [stream open];
            
            self.inputStreams[peerID] = stream;
        }
    });
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    // complete delegate protocol
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    // complete delegate protocol
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([stream isKindOfClass:[NSInputStream class]])
        {
            [self inputStream:(NSInputStream *)stream handleEvent:eventCode];
        }
        else
        {
            [self outputStream:(NSOutputStream *)stream handleEvent:eventCode];
        }
    });
}

- (void)inputStream:(NSInputStream *)inputStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode)
    {
        case NSStreamEventNone:
        {
            DLog(@"Input stream: %@ has no event", inputStream);
            break;
        }
            
            
        case NSStreamEventEndEncountered:
        {
            DLog(@"Input stream %@ end encountered", inputStream);
            break;
        }
            
        case NSStreamEventErrorOccurred:
        {
            DLog(@"Input stream %@ error occured", inputStream);
            break;
        }
            
        case NSStreamEventHasBytesAvailable:
        {
            DLog(@"New Data!");
            [self receiveLatencyDataFromInputStream:inputStream];
            break;
        }
            
        case NSStreamEventHasSpaceAvailable:
        {
            DLog(@"Input stream %@ has space available", inputStream);
            break;
        }
            
        case NSStreamEventOpenCompleted:
        {
            DLog(@"Input stream %@ open completed", inputStream);
            break;
        }
    }
}

- (void)outputStream:(NSOutputStream *)outputStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode)
    {
        case NSStreamEventNone:
        {
            DLog(@"Output stream: %@ has no event", outputStream);
            break;
        }
            
            
        case NSStreamEventEndEncountered:
        {
            DLog(@"Output stream %@ end encountered", outputStream);
            break;
        }
            
        case NSStreamEventErrorOccurred:
        {
            DLog(@"Output stream %@ error occured", outputStream);
            break;
        }
            
        case NSStreamEventHasBytesAvailable:
        {
            //DLog(@"Output stream %@ has bytes available", outputStream);
            break;
        }
            
        case NSStreamEventHasSpaceAvailable:
        {
            //DLog(@"Output stream %@ has space available", outputStream);
            break;
        }
            
        case NSStreamEventOpenCompleted:
        {
            DLog(@"Output stream %@ open completed", outputStream);
            break;
        }
    }
}


@end
