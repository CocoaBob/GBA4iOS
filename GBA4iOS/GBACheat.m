//
//  GBACheat.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACheat.h"

@implementation GBACheat

#pragma mark - Initializing

- (instancetype)initWithName:(NSString *)name codes:(NSArray *)codes
{
    self = [super init];
    if (self)
    {
        _name = [name copy];
        _codes = [codes copy];
    }
    
    return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.codes forKey:@"codes"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = [aDecoder decodeObjectForKey:@"name"];
    NSArray *codes = [aDecoder decodeObjectForKey:@"codes"];
    
    return [self initWithName:name codes:codes];
}

#pragma mark - Misc.

- (NSString *)description
{
    return [NSString stringWithFormat:@"Name: %@\nCodes: %@", self.name, self.codes];
}

@end
