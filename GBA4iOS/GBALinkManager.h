//
//  GBALinkManager.h
//  GBA4iOS
//
//  Created by Riley Testut on 4/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

// Can't use @import in C++ linked code :(
#import <MultipeerConnectivity/MultipeerConnectivity.h>

extern NSString *const GBALinkSessionServiceType;

typedef NS_ENUM(NSUInteger, GBALinkPeerType) {
    GBALinkPeerTypeUnknown = 0,
    GBALinkPeerTypeClient  = 1,
    GBALinkPeerTypeServer  = 2,
};

@class GBALinkManager;

@protocol GBALinkManagerDelegate <NSObject>

@optional
- (void)linkManager:(GBALinkManager *)linkManager peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state;

@end

@interface GBALinkManager : NSObject

@property (weak, nonatomic) id<GBALinkManagerDelegate> delegate;
@property (readonly, assign, nonatomic) GBALinkPeerType peerType;

@property (readonly, strong, nonatomic) MCSession *session;

+ (instancetype)sharedManager;

- (void)start;
- (void)stop;

- (int)sendData:(const char *)data withSize:(size_t)size toPeerAtIndex:(int)index;
- (int)receiveData:(char *)data withMaxSize:(size_t)maxSize fromPeerAtIndex:(int)index;

@end
