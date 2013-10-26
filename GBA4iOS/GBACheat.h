//
//  GBACheat.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GBACheatCodeType)
{
    GBACheatCodeTypeCodeBreaker,
    GBACheatCodeTypeGameSharkV3,
    GBACheatCodeTypeActionReplay,
    GBACheatCodeTypeGameGenie,
    GBACheatCodeTypeGameSharkGBC,
};

@interface GBACheat : NSObject <NSCoding, NSCopying>

@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSArray /* NSString */ *codes; // One cheat can consist of multiple codes.
@property (readonly, copy, nonatomic) NSString *uid;
@property (assign, nonatomic) BOOL enabled;
@property (assign, nonatomic) GBACheatCodeType type;

- (instancetype)initWithName:(NSString *)name codes:(NSArray *)codes;

@end
