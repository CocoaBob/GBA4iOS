//
//  GBALinkManager.m
//  GBA4iOS
//
//  Created by Riley Testut on 4/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBALinkManager.h"
#import "GBAEmulatorCore.h"

#import "UIAlertView+RSTAdditions.h"
#import "MCPeerID+Conveniences.h"

NSString *const GBALinkSessionServiceType = @"gba4ios-link";

@interface GBALinkManager () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, NSStreamDelegate>
{
    BOOL _testingLatency;
}

@property (readwrite, assign, nonatomic) GBALinkPeerType peerType;
@property (readwrite, assign, nonatomic, getter=isLinkConnected) BOOL linkConnected;

@property (strong, nonatomic) MCNearbyServiceAdvertiser *nearbyServiceAdvertiser;
@property (strong, nonatomic) MCNearbyServiceBrowser *nearbyServiceBrowser;

@property (strong, nonatomic) NSMutableDictionary *outputStreams;
@property (strong, nonatomic) NSMutableDictionary *inputStreams;

@property (strong, nonatomic) NSMutableArray *orderedPeers;

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
        
        _orderedPeers = [NSMutableArray array];
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
    
    [self.session disconnect];
}

- (void)resetLink
{
    DLog("Resetting Link...");
    
    [self.outputStreams removeAllObjects];
    [self.inputStreams removeAllObjects];
    [self.orderedPeers removeAllObjects];
    
    [[GBAEmulatorCore sharedCore] stopLink];
    self.linkConnected = NO;
}

- (void)sendPeerType:(GBALinkPeerType)peerType toPeer:(MCPeerID *)peerID
{
    NSData *data = [NSData dataWithBytes:&peerType length:sizeof(peerType)];
    [self.session sendData:data toPeers:@[peerID] withMode:MCSessionSendDataReliable error:nil];
}

- (void)connectOutputStreamToPeer:(MCPeerID *)peerID
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSError *error = nil;
        NSOutputStream *outputStream = [self.session startStreamWithName:[[UIDevice currentDevice] name] toPeer:peerID error:&error];
        
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

#pragma mark - Emulation Link -

- (void)startEmulationLink
{
    [[GBAEmulatorCore sharedCore] startLinkWithConnectionType:GBALinkConnectionTypeLinkCable peerType:self.peerType completion:^(BOOL success) {
        
        DLog("Success Linking! %d", success);
        
        if (success)
        {
            self.linkConnected = YES;
        }
        else
        {
            self.linkConnected = NO;
        }
        
    }];
}

#pragma mark - Streaming Data -

- (NSInteger)sendData:(const char *)data withSize:(size_t)size toPlayerAtIndex:(NSInteger)index
{
    if (self.peerType == GBALinkPeerTypeServer)
    {
        index--;
    }
    
    if (index >= (NSInteger)[[self.session connectedPeers] count])
    {
        return 0;
    }
    
    MCPeerID *peerID = self.orderedPeers[index];
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
    
    MCPeerID *peerID = self.orderedPeers[index];
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
    @autoreleasepool
    {
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        
        NSArray *inputStreams = [self.inputStreams allValues];
        
        while (![self hasBytesAvailableFromInputStreams:inputStreams] && CFAbsoluteTimeGetCurrent() - startTime < timeout);
        
        return [self hasBytesAvailableFromInputStreams:inputStreams];
    }
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

- (BOOL)hasLinkDataAvailable:(int *)index
{
    NSArray *inputStreams = [self.inputStreams allValues];
    
    if (index)
    {
        if (self.peerType == GBALinkPeerTypeServer)
        {
            *index = 1;
        }
        else
        {
            *index = 0;
        }
    }
    
    return [self hasBytesAvailableFromInputStreams:inputStreams];
}

#pragma mark - MCNearbyServiceAdvertiserDelagate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession *))invitationHandler
{
    if ([self isLinkConnected])
    {
        invitationHandler(NO, self.session);
        return;
    }
    
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
        GBALinkPeerType peerType = GBALinkPeerTypeUnknown;
        
        if (self.peerType == GBALinkPeerTypeClient)
        {
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
        else if (self.peerType == GBALinkPeerTypeServer)
        {
            if (![self.outputStreams objectForKey:peerID])
            {
                [self.orderedPeers addObject:peerID];
                [self connectOutputStreamToPeer:peerID];
            }
        }
    }
    else if (state == MCSessionStateNotConnected)
    {
        if ([[session connectedPeers] count] == 0)
        {
            [self resetLink];
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
        
        if (self.peerType == GBALinkPeerTypeServer)
        {
            if (![self.outputStreams objectForKey:peerID])
            {
                [self.orderedPeers addObject:peerID];
                [self connectOutputStreamToPeer:peerID];
            }
        }
    }
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
            
            [self startEmulationLink];
        }
        
        if (self.peerType == GBALinkPeerTypeClient)
        {
            if (![self.outputStreams objectForKey:peerID])
            {
                [self.orderedPeers addObject:peerID];
                [self connectOutputStreamToPeer:peerID];
            }
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
            //[self receiveLatencyDataFromInputStream:inputStream];
            
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
