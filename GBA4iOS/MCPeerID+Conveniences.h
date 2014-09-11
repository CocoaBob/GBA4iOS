//
//  MCPeerID+ConnectionState.h
//  GBA4iOS
//
//  Created by Riley Testut on 4/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MCPeerID (Conveniences)

@property (assign, nonatomic) MCSessionState rst_state;
@property (copy, nonatomic) NSDictionary *rst_discoveryInfo;

@end
