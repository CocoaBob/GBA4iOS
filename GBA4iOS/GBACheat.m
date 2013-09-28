//
//  GBACheat.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACheat.h"

@interface GBACheat ()

@property (readwrite, copy, nonatomic) NSString *uid;

@end

@implementation GBACheat

#pragma mark - Initializing

- (instancetype)initWithName:(NSString *)name codes:(NSArray *)codes
{
    self = [super init];
    if (self)
    {
        _name = [name copy];
        _codes = [codes copy];
        
        NSUUID *uid = [[NSUUID alloc] init];
        _uid = [[uid UUIDString] copy];
        
        _enabled = YES;
    }
    
    return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.codes forKey:@"codes"];
    [aCoder encodeObject:self.uid forKey:@"uid"];
    [aCoder encodeObject:@(self.enabled) forKey:@"enabled"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = [aDecoder decodeObjectForKey:@"name"];
    NSArray *codes = [aDecoder decodeObjectForKey:@"codes"];
    NSString *uid = [aDecoder decodeObjectForKey:@"uid"];
    NSNumber *enabled = [aDecoder decodeObjectForKey:@"enabled"];
    
    self = [self initWithName:name codes:codes];
    self.uid = uid;
    self.enabled = [enabled boolValue];
    
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    GBACheat *cheat = [[GBACheat alloc] init];
    cheat.name = self.name;
    cheat.codes = self.codes;
    cheat.uid = self.uid;
    cheat.enabled = self.enabled;
    
    return cheat;
}

#pragma mark - Misc.

- (NSString *)description
{
    return [NSString stringWithFormat:@"Name: %@\nCodes: %@", self.name, self.codes];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GBACheat class]])
    {
        return NO;
    }
    
    return [self.uid isEqualToString:[(GBACheat *)object uid]];
}

- (NSUInteger)hash
{
    return [self.uid hash];
}

@end
