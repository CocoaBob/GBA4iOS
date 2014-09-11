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

@property (readwrite, assign, nonatomic) GBALinkPeerType peerType;

@property (strong, nonatomic) MCNearbyServiceAdvertiser *nearbyServiceAdvertiser;
@property (strong, nonatomic) MCNearbyServiceBrowser *nearbyServiceBrowser;

@property (strong, nonatomic) NSMutableData *inputDataBuffer;

@property (strong, nonatomic) dispatch_semaphore_t input_data_dispatch_semaphore;
@property (strong, nonatomic) dispatch_queue_t input_data_dispatch_queue;

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
        
        _inputDataBuffer = [NSMutableData data];
        
        _input_data_dispatch_queue = dispatch_queue_create("com.rileytestut.GBA4iOS.input_data_dispatch_queue", DISPATCH_QUEUE_SERIAL);
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

#pragma mark - Emulator Link

- (int)sendData:(const char *)data withSize:(size_t)size toPeerAtIndex:(int)index
{
    MCPeerID *peerID = [self.session connectedPeers][index];
    
    NSError *error = nil;
    if (![self.session sendData:[NSData dataWithBytes:data length:size] toPeers:@[peerID] withMode:MCSessionSendDataReliable error:&error])
    {
        ELog(error);
    }
    
    return (int)size;
}

- (int)receiveData:(char *)data withMaxSize:(size_t)maxSize fromPeerAtIndex:(int)index
{
    MCPeerID *peerID = [self.session connectedPeers][index];
    
    int receivedBytes = 0;
    
    if ([self.inputDataBuffer length] == 0)
    {
        self.input_data_dispatch_semaphore = dispatch_semaphore_create(0);
        dispatch_semaphore_wait(self.input_data_dispatch_semaphore, DISPATCH_TIME_FOREVER);
        self.input_data_dispatch_semaphore = nil;
    }
    
    if ([self.inputDataBuffer length] > 0)
    {
        NSRange range = NSMakeRange(0, MIN(maxSize, self.inputDataBuffer.length));
        
        [self.inputDataBuffer getBytes:(void *)data range:range];
        [self.inputDataBuffer replaceBytesInRange:range withBytes:NULL length:0];
        
        receivedBytes = (int)range.length;
    }
    
    return receivedBytes;
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
    
    [self.inputDataBuffer appendData:data];
    
    if (self.input_data_dispatch_semaphore)
    {
        dispatch_semaphore_signal(self.input_data_dispatch_semaphore);
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    // complete delegate protocol
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    // complete delegate protocol
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    // complete delegate protocol
}

@end
