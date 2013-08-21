//
//  GBACheat.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GBACheat : NSObject <NSCoding>

@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSArray /* NSString */ *codes; // One cheat can consist of multiple codes.

- (instancetype)initWithName:(NSString *)name codes:(NSArray *)codes;

@end
