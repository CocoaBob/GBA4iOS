//
//  GBAPeer.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/15/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GBAPeerState)
{
    GBAPeerStateDisconnected = 0,
    GBAPeerStateConnecting,
    GBAPeerStateConnected,
};

@interface GBAPeer : NSObject

@property (copy, nonatomic, readonly) NSString *name;
@property (assign, nonatomic, readonly) NSInteger playerIndex;
@property (copy, nonatomic, readonly) NSUUID *identifier;
@property (assign, nonatomic, readonly) GBAPeerState state;

@end
