//
//  MCPeerID+ConnectionState.m
//  GBA4iOS
//
//  Created by Riley Testut on 4/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "MCPeerID+Conveniences.h"

#import <objc/runtime.h>

@implementation MCPeerID (Conveniences)
@dynamic rst_state;
@dynamic rst_discoveryInfo;

- (void)setRst_state:(MCSessionState)rst_state
{
    NSNumber *value = @(rst_state);
    
    if (rst_state == MCSessionStateNotConnected)
    {
        value = nil;
    }
    
    objc_setAssociatedObject(self, @selector(rst_state), value, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (MCSessionState)rst_state
{
    return [objc_getAssociatedObject(self, @selector(rst_state)) integerValue];
}

- (void)setRst_discoveryInfo:(NSDictionary *)rst_discoveryInfo
{
    objc_setAssociatedObject(self, @selector(rst_discoveryInfo), rst_discoveryInfo, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSDictionary *)rst_discoveryInfo
{
    return objc_getAssociatedObject(self, @selector(rst_discoveryInfo));
}

@end
