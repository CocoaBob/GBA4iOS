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
@property (readwrite, copy, nonatomic) NSString *filepath;

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
    }
    
    return self;
}

- (instancetype)initWithContentsOfFile:(NSString *)filepath
{
    self = [NSKeyedUnarchiver unarchiveObjectWithFile:filepath];
    
    self.filepath = filepath;
    
    return self;
}

+ (GBACheat *)cheatWithContentsOfFile:(NSString *)filepath
{
    return [[GBACheat alloc] initWithContentsOfFile:filepath];
}

- (void)writeToFile:(NSString *)filepath
{
    self.filepath = filepath;
    [NSKeyedArchiver archiveRootObject:self toFile:filepath];
}

- (void)generateNewUID
{
    self.uid = [[NSUUID UUID] UUIDString];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:NSStringFromSelector(@selector(name))];
    [aCoder encodeObject:self.codes forKey:NSStringFromSelector(@selector(codes))];
    [aCoder encodeObject:self.uid forKey:NSStringFromSelector(@selector(uid))];
    [aCoder encodeObject:@(self.type) forKey:NSStringFromSelector(@selector(type))];
    [aCoder encodeObject:@(self.index) forKey:NSStringFromSelector(@selector(index))];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(name))];
    NSArray *codes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(codes))];
    NSString *uid = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(uid))];
    NSNumber *type = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(type))];
    NSNumber *index = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(index))];
    
    self = [self initWithName:name codes:codes];
    self.uid = uid;
    self.type = [type integerValue];
    self.index = [index unsignedIntegerValue];
    
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    GBACheat *cheat = [[GBACheat alloc] init];
    cheat.name = self.name;
    cheat.codes = self.codes;
    cheat.uid = self.uid;
    cheat.type = self.type;
    cheat.index = self.index;
    cheat.filepath = self.filepath;
    
    return cheat;
}

#pragma mark - Misc.

- (NSString *)description
{
    NSString *codeType = @"Code Breaker";
    
    if (self.type == GBACheatCodeTypeGameSharkV3)
    {
        codeType = @"GameShark V3";
    }
    else if (self.type == GBACheatCodeTypeActionReplay)
    {
        codeType = @"Action Replay";
    }
    
    return [NSString stringWithFormat:@"Name: %@\nType: %@\nIndex: %lu\nCodes: %@", self.name, codeType, (unsigned long)self.index, self.codes];
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
